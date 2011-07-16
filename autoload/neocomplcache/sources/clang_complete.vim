" original: http://github.com/Rip-Rip/clang_complete

" File: clang_complete.vim
" Author: Xavier Deguillard <deguilx@gmail.com>
" Modified by: eagletmt <eagletmt@gmail.com>
"              Shougo Matsushita <Shougo.Matsu At gmail.com>
"
" Description: Use of clang to complete in C/C++.
"
" Configuration: Each project can have a .clang_complete at his root,
"                containing the compiler options. This is useful if
"                you're using some non-standard include paths.
"                For simplicity, please don't put relative and
"                absolute include path on the same line. It is not
"                currently correctly handled.
"
" Todo: - Fix bugs
"       - Add snippets on Pattern and OVERLOAD (is it possible?)
"

" Variables initialize.
if !exists('g:neocomplcache_clang_complete_use_library')
  let g:neocomplcache_clang_complete_use_library = 0
endif
if !exists('g:neocomplcache_clang_complete_macros')
    let g:neocomplcache_clang_complete_macros = 0
endif
if !exists('g:neocomplcache_clang_complete_patterns')
    let g:neocomplcache_clang_complete_patterns = 0
endif
if !exists('g:neocomplcache_clang_complete_auto_options')
    let g:neocomplcache_clang_complete_auto_options = 'path, .clang_complete'
endif
if !exists('g:neocomplcache_clang_complete_user_options')
    let g:neocomplcache_clang_complete_user_options = ''
endif

let s:source = {
      \ 'name': 'clang_complete',
      \ 'kind': 'ftplugin',
      \ 'filetypes': { 'c': 1, 'cpp': 1, 'objc': 1, 'objcpp': 1 },
      \ }

" Store plugin path, as this is available only when sourcing the file,
" not during a function call.
let s:plugin_path = escape(expand('<sfile>:p:h'), '\')

function! s:init_ClangCompletePython()
  python import sys

  if exists('g:neocomplcache_clang_complete_library_path')
    " Load the library from the given library path.
    execute 'python sys.argv = ["' . escape(g:neocomplcache_clang_complete_library_path, '\') . '"]'
  else
    " By setting argv[0] to '' force the python bindings to load the library
    " from the normal system search path.
    python sys.argv[0] = ''
  endif

  execute 'python sys.path = ["' . s:plugin_path . '/clang_complete"] + sys.path'
  execute 'pyfile ' . s:plugin_path . '/clang_complete/libclang.py'
  python initClangComplete(vim.eval('g:neocomplcache_clang_complete_lib_flags'))
endfunction

function! s:init_ClangComplete()
    let b:should_overload = 0

    call LoadUserOptions()

    let b:clang_exec = 'clang'
    let b:clang_parameters = '-x c'

    if &filetype == 'objc'
        let b:clang_parameters = '-x objective-c'
    endif

    if &filetype == 'cpp' || &filetype == 'objcpp'
        let b:clang_parameters .= '++'
    endif

    if expand('%:e') =~ 'h*'
        let b:clang_parameters .= '-header'
    endif

    let g:neocomplcache_clang_complete_lib_flags = 0
    if g:neocomplcache_clang_complete_macros
        let b:clang_parameters .= ' -code-completion-macros'
        let g:neocomplcache_clang_complete_lib_flags = 1
    endif
    if g:neocomplcache_clang_complete_patterns
        let b:clang_parameters .= ' -code-completion-patterns'
        let g:clang_complete_lib_flags += 2
    endif

    " Load the python bindings of libclang.
    if g:neocomplcache_clang_complete_use_library
      if has('python')
        call s:init_ClangCompletePython()
      else
        echoe 'clang_complete: No python support available.'
        echoe 'Cannot use clang library, using executable'
        echoe 'Compile vim with python support to use libclang'
        let g:neocomplcache_clang_complete_use_library = 0
        return
      endif
    endif
endfunction

function! LoadUserOptions()
    let b:clang_user_options = ''

    let l:option_sources = split(g:neocomplcache_clang_complete_auto_options, ',')
    let l:remove_spaces_cmd = 'substitute(v:val, "\\s*\\(.*\\)\\s*", "\\1", "")'
    let l:option_sources = map(l:option_sources, l:remove_spaces_cmd)

    for l:source in l:option_sources
        if l:source == 'path'
            call s:parsePathOption()
        elseif l:source == '.clang_complete'
            call s:parseConfig()
        endif
    endfor
endfunction

function! s:parseConfig()
    let l:local_conf = findfile('.clang_complete', '.;')
    if l:local_conf == '' || !filereadable(l:local_conf)
        return
    endif

    let l:opts = readfile(l:local_conf)
    for l:opt in l:opts
        " Better handling of absolute path
        " I don't know if those pattern will work on windows
        " platform
        if matchstr(l:opt, '\C-I\s*/') != ''
            let l:opt = substitute(l:opt, '\C-I\s*\(/\%(\w\|\\\s\)*\)',
                        \ '-I' . '\1', 'g')
        else
            let l:opt = substitute(l:opt, '\C-I\s*\(\%(\w\|\\\s\)*\)',
                        \ '-I' . l:local_conf[:-16] . '\1', 'g')
        endif
        let b:clang_user_options .= ' ' . l:opt
    endfor
endfunction

function! s:parsePathOption()
    let l:dirs = split(&path, ',')
    for l:dir in l:dirs
        if len(l:dir) == 0 || !isdirectory(l:dir)
            continue
        endif

        " Add only absolute paths
        if matchstr(l:dir, '\s*/') != ''
            let l:opt = '-I' . l:dir
            let b:clang_user_options .= ' ' . l:opt
        endif
    endfor
endfunction

function! s:get_kind(proto)
    if a:proto == ""
        return 't'
    endif
    let l:ret = match(a:proto, '^\[#')
    let l:params = match(a:proto, '(')
    if l:ret == -1 && l:params == -1
        return 't'
    endif
    if l:ret != -1 && l:params == -1
        return 'v'
    endif
    if l:params != -1
        return 'f'
    endif
    return 'm'
endfunction

function! s:source.initialize()
    autocmd neocomplcache FileType c,cpp,objc,objcpp call s:init_ClangComplete()
    if &l:filetype == 'c' || &l:filetype == 'cpp' || &l:filetype == 'objc' || &l:filetype == 'objcpp'
        call s:init_ClangComplete()
    endif

    call neocomplcache#set_completion_length('clang_complete', 0)
endfunction

function! s:source.finalize()
endfunction

function! s:ClangQuickFix(clang_output)
    let l:list = []
    for l:line in a:clang_output
        let l:erridx = stridx(l:line, "error:")
        if l:erridx == -1
            continue
        endif
        let l:bufnr = bufnr("%")
        let l:pattern = '\.*:\(\d*\):\(\d*\):'
        let tmp = matchstr(l:line, l:pattern)
        let l:lnum = substitute(tmp, l:pattern, '\1', '')
        let l:col = substitute(tmp, l:pattern, '\2', '')
        let l:text = l:line
        let l:type = 'E'
        let l:item = {
                    \ "bufnr": l:bufnr,
                    \ "lnum": l:lnum,
                    \ "col": l:col,
                    \ "text": l:text[l:erridx + 7:],
                    \ "type": l:type }
        let l:list = add(l:list, l:item)
    endfor
    call setqflist(l:list)
endfunction

function! s:DemangleProto(prototype)
    let l:proto = substitute(a:prototype, '[#', '', 'g')
    let l:proto = substitute(l:proto, '#]', ' ', 'g')
    let l:proto = substitute(l:proto, '#>', '', 'g')
    let l:proto = substitute(l:proto, '<#', '', 'g')
    " TODO: add a candidate for each optional parameter
    let l:proto = substitute(l:proto, '{#', '', 'g')
    let l:proto = substitute(l:proto, '#}', '', 'g')

    return l:proto
endfunction

function! s:source.get_keyword_pos(cur_text)
    let l:line = getline('.')
    let l:start = col('.') - 1
    let l:wsstart = l:start
    if l:line[l:wsstart - 1] =~ '\s'
        while l:wsstart > 0 && l:line[l:wsstart - 1] =~ '\s'
            let l:wsstart -= 1
        endwhile
    endif
    if l:line[l:wsstart - 1] =~ '[(,]'
        let b:should_overload = 1
        return l:wsstart
    endif
    let b:should_overload = 0
    while l:start > 0 && l:line[l:start - 1] =~ '\i'
        let l:start -= 1
    endwhile
    return l:start
endfunction

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)
    if neocomplcache#is_auto_complete()
          \ && getline('.') !~ '\%(->\|\.\|::\)$'
          " \ && len(a:cur_keyword_str) < g:neocomplcache_auto_completion_start_length
        " auto complete is very slow!
        return []
    endif

    if g:neocomplcache_clang_complete_use_library
        python vim.command('let l:clang_output = ' + str(getCurrentCompletions(vim.eval('a:cur_keyword_str'), int(vim.eval('a:cur_keyword_pos+1')))))
        " echomsg string(l:clang_output)
    else
        let l:clang_output = s:complete_from_clang_binary(a:cur_keyword_pos)
    endif

    return l:clang_output
endfunction

function! s:complete_from_clang_binary(cur_keyword_pos)
    let l:buf = getline(1, '$')
    let l:tempfile = expand('%:p:h') . '/' . localtime() . expand('%:t')
    if neocomplcache#is_win()
        let l:tempfile = substitute(l:tempfile, '\\', '/', 'g')
    endif
    call writefile(l:buf, l:tempfile)
    let l:escaped_tempfile = shellescape(l:tempfile)

    let l:command = b:clang_exec . ' -cc1 -fsyntax-only'
                \ . ' -fno-caret-diagnostics -fdiagnostics-print-source-range-info'
                \ . ' -code-completion-at='
                \ . l:escaped_tempfile . ":" . line('.') . ":" . (a:cur_keyword_pos+1)
                \ . ' ' . l:escaped_tempfile
                \ . ' ' . b:clang_parameters . ' ' . b:clang_user_options . ' ' . g:neocomplcache_clang_complete_user_options
    let l:clang_output = split(neocomplcache#system(l:command), '\n')

    call delete(l:tempfile)

    let l:filter_str = "v:val =~ '^COMPLETION: " . a:base . "\\|^OVERLOAD: '"
    call filter(l:clang_output, l:filter_str)

    let l:res = []
    for l:line in l:clang_output

        if l:line[:11] == 'COMPLETION: ' && b:should_overload != 1

            let l:value = l:line[12:]

            let l:colonidx = stridx(l:value, ' : ')
            if l:colonidx == -1
                let l:wabbr = s:DemangleProto(l:value)
                let l:word = l:value
                let l:proto = l:value
            else
                let l:word = l:value[:l:colonidx - 1]
                " WTF is that?
                if l:word =~ '(Hidden)'
                    let l:word = l:word[:-10]
                endif
                let l:wabbr = l:word
                let l:proto = l:value[l:colonidx + 3:]
            endif

            let l:kind = s:GetKind(l:proto)
            if l:kind == 't' && b:clang_complete_type == 0
                continue
            endif

            let l:word = l:wabbr
            let l:proto = s:DemangleProto(l:proto)

        elseif l:line[:9] == 'OVERLOAD: ' && b:should_overload == 1

            let l:value = l:line[10:]
            if match(l:value, '<#') == -1
                continue
            endif
            let l:word = substitute(l:value, '.*<#', '<#', 'g')
            let l:word = substitute(l:word, '#>.*', '#>', 'g')
            let l:wabbr = substitute(l:word, '<#\([^#]*\)#>', '\1', 'g')
            let l:proto = s:DemangleProto(l:value)
            let l:kind = ''
        else
            continue
        endif

        let l:item = {
                    \ 'word': l:word,
                    \ 'abbr': l:wabbr,
                    \ 'menu': l:proto,
                    \ 'info': l:proto,
                    \ 'dup': 1,
                    \ 'kind': l:kind }

        call add(l:res, l:item)
    endfor

    return l:res
endfunction

function! neocomplcache#sources#clang_complete#define()
    return s:source
endfunction

" vim: expandtab:ts=4:sts=4:sw=4
