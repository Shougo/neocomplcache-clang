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

" Variables initialize.
let g:neocomplcache_clang_use_library =
      \ get(g:, 'neocomplcache_clang_use_library', 0)
let g:neocomplcache_clang_macros =
      \ get(g:, 'neocomplcache_clang_macros', 0)
let g:neocomplcache_clang_patterns =
      \ get(g:, 'neocomplcache_clang_patterns', 0)
let g:neocomplcache_clang_auto_options =
      \ get(g:, 'neocomplcache_clang_auto_options', 'path, .clang_complete')
let g:neocomplcache_clang_user_options =
      \ get(g:, 'neocomplcache_clang_user_options', '')
let g:neocomplcache_clang_debug =
      \ get(g:, 'neocomplcache_clang_debug', 0)
let g:neocomplcache_clang_executable_path =
      \ get(g:, 'neocomplcache_clang_library_path', 'clang')

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

  if exists('g:neocomplcache_clang_library_path')
    " Load the library from the given library path.
    execute 'python sys.argv = ["' . escape(g:neocomplcache_clang_library_path, '\') . '"]'
  else
    " By setting argv[0] to '' force the python bindings to load the library
    " from the normal system search path.
    python sys.argv[0] = ''
  endif

  execute 'python sys.path = ["' . s:plugin_path . '/clang_complete"] + sys.path'
  execute 'pyfile ' . s:plugin_path . '/clang_complete/libclang.py'
  python initClangComplete(vim.eval('g:neocomplcache_clang_lib_flags'))
endfunction

function! s:init_ClangComplete()
  let b:should_overload = 0

  call s:loadUserOptions()

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

  let g:neocomplcache_clang_lib_flags = 0
  if g:neocomplcache_clang_macros
    let b:clang_parameters .= ' -code-completion-macros'
    let g:neocomplcache_clang_lib_flags = 1
  endif
  if g:neocomplcache_clang_patterns
    let b:clang_parameters .= ' -code-completion-patterns'
    let g:clang_complete_lib_flags += 2
  endif

  " Load the python bindings of libclang.
  if g:neocomplcache_clang_use_library
    if has('python')
      call s:init_ClangCompletePython()
    else
      echoe 'clang_complete: No python support available.'
      echoe 'Cannot use clang library, using executable'
      echoe 'Compile vim with python support to use libclang'
      let g:neocomplcache_clang_use_library = 0
      return
    endif
  endif
endfunction

function! s:loadUserOptions()
  let b:neocomplcache_clang_user_options = ''

  let option_sources = split(g:neocomplcache_clang_auto_options, ',')
  let remove_spaces_cmd = 'substitute(v:val, "\\s*\\(.*\\)\\s*", "\\1", "")'
  let option_sources = map(option_sources, remove_spaces_cmd)

  for source in option_sources
    if source == 'path'
      call s:parsePathOption()
    elseif source == '.clang_complete'
      call s:parseConfig()
    endif
  endfor
endfunction

function! s:parseConfig()
  let local_conf = findfile('.clang_complete', '.;')
  if local_conf == '' || !filereadable(local_conf)
    return
  endif

  let opts = readfile(local_conf)
  for opt in opts
    " Better handling of absolute path
    " I don't know if those pattern will work on windows
    " platform
    if matchstr(opt, '\C-I\s*/') != ''
      let opt = substitute(opt, '\C-I\s*\(/\%(\w\|\\\s\)*\)',
            \ '-I' . '\1', 'g')
    else
      let opt = substitute(opt, '\C-I\s*\(\%(\w\|\\\s\)*\)',
            \ '-I' . local_conf[:-16] . '\1', 'g')
    endif
    let b:neocomplcache_clang_user_options .= ' ' . opt
  endfor
endfunction

function! s:parsePathOption()
  let dirs = split(&path, ',')
  for dir in dirs
    if len(dir) == 0 || !isdirectory(dir)
      continue
    endif

    " Add only absolute paths
    if matchstr(dir, '\s*/') != ''
      let opt = '-I' . dir
      let b:neocomplcache_clang_user_options .= ' ' . opt
    endif
  endfor
endfunction

function! s:get_kind(proto)
  if a:proto == ""
    return 't'
  endif
  let ret = match(a:proto, '^\[#')
  let params = match(a:proto, '(')
  if ret == -1 && params == -1
    return 't'
  endif
  if ret != -1 && params == -1
    return 'v'
  endif
  if params != -1
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
  let list = []
  for line in a:clang_output
    let erridx = stridx(line, "error:")
    if erridx == -1
      continue
    endif
    let bufnr = bufnr("%")
    let pattern = '\.*:\(\d*\):\(\d*\):'
    let tmp = matchstr(line, pattern)
    let lnum = substitute(tmp, pattern, '\1', '')
    let col = substitute(tmp, pattern, '\2', '')
    let text = line
    let type = 'E'
    let item = {
          \ "bufnr": bufnr,
          \ "lnum": lnum,
          \ "col": col,
          \ "text": text[erridx + 7:],
          \ "type": type }
    let list = add(list, item)
  endfor
  call setqflist(list)
endfunction

function! s:DemangleProto(prototype)
  let proto = substitute(a:prototype, '[#', '', 'g')
  let proto = substitute(proto, '#]', ' ', 'g')
  let proto = substitute(proto, '#>', '', 'g')
  let proto = substitute(proto, '<#', '', 'g')
  " TODO: add a candidate for each optional parameter
  let proto = substitute(proto, '{#', '', 'g')
  let proto = substitute(proto, '#}', '', 'g')

  return proto
endfunction

function! s:source.get_keyword_pos(cur_text)
  if neocomplcache#is_auto_complete()
        \ && a:cur_text !~ '\%(->\|\.\|::\)\%(\h\w*\)\?$'
    " auto complete is very slow!
    return -1
  endif

  let line = getline('.')

  let start = col('.') - 1
  let wsstart = start
  if line[wsstart - 1] =~ '\s'
    while wsstart > 0 && line[wsstart - 1] =~ '\s'
      let wsstart -= 1
    endwhile
  endif
  if line[wsstart - 1] =~ '[(,]'
    let b:should_overload = 1
    return wsstart
  endif
  let b:should_overload = 0
  while start > 0 && line[start - 1] =~ '\i'
    let start -= 1
  endwhile
  return start
endfunction

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)
  if bufname('%') == ''
    return []
  endif

  if g:neocomplcache_clang_use_library
    python vim.command('let clang_output = ' + str(getCurrentCompletions(vim.eval('a:cur_keyword_str'), int(vim.eval('a:cur_keyword_pos+1')))))
    " echomsg string(clang_output)
  else
    let clang_output = s:complete_from_clang_binary(a:cur_keyword_pos, a:cur_keyword_str)
  endif

  return clang_output
endfunction

function! s:complete_from_clang_binary(cur_keyword_pos, cur_keyword_str)
  if !executable(g:neocomplcache_clang_executable_path)
    return []
  endif

  let buf = getline(1, '$')
  let tempfile = expand('%:p:h') . '/' . localtime() . expand('%:t')
  if neocomplcache#is_win()
    let tempfile = substitute(tempfile, '\\', '/', 'g')
  endif
  call writefile(buf, tempfile)
  let escaped_tempfile = shellescape(tempfile)

  let command = g:neocomplcache_clang_executable_path . ' -cc1 -fsyntax-only'
        \ . ' -fno-caret-diagnostics -fdiagnostics-print-source-range-info'
        \ . ' -code-completion-at='
        \ . escaped_tempfile . ":" . line('.') . ":" . (a:cur_keyword_pos+1)
        \ . ' ' . escaped_tempfile
        \ . ' ' . b:clang_parameters . ' ' . b:neocomplcache_clang_user_options . ' ' . g:neocomplcache_clang_user_options
  let clang_output = split(neocomplcache#system(command), '\n')

  call delete(tempfile)

  let filter_str = "v:val =~ '^COMPLETION: " . a:cur_keyword_str . "\\|^OVERLOAD: '"
  call filter(clang_output, filter_str)

  let res = []
  for line in clang_output

    if line[:11] == 'COMPLETION: ' && b:should_overload != 1

      let value = line[12:]

      let colonidx = stridx(value, ' : ')
      if colonidx == -1
        let wabbr = s:DemangleProto(value)
        let word = value
        let proto = value
      else
        let word = value[:l:colonidx - 1]
        " WTF is that?
        if word =~ '(Hidden)'
          let word = word[:-10]
        endif
        let wabbr = word
        let proto = value[colonidx + 3:]
      endif

      let kind = s:GetKind(proto)
      if kind == 't' && getline('.') =~ '\%(->\|\.\|::\)$'
        continue
      endif

      let word = wabbr
      let proto = s:DemangleProto(proto)

    elseif line[:9] == 'OVERLOAD: ' && b:should_overload == 1

      let value = line[10:]
      if match(value, '<#') == -1
        continue
      endif
      let word = substitute(value, '.*<#', '<#', 'g')
      let word = substitute(word, '#>.*', '#>', 'g')
      let wabbr = substitute(word, '<#\([^#]*\)#>', '\1', 'g')
      let proto = s:DemangleProto(value)
      let kind = ''
    else
      continue
    endif

    let item = {
          \ 'word': word,
          \ 'abbr': wabbr,
          \ 'menu': proto,
          \ 'info': proto,
          \ 'dup': 1,
          \ 'kind': kind }

    call add(res, item)
  endfor

  return res
endfunction

function! s:GetKind(proto)
  if a:proto == ''
    return 't'
  endif
  let ret = match(a:proto, '^\[#')
  let params = match(a:proto, '(')
  if ret == -1 && params == -1
    return 't'
  endif
  if ret != -1 && params == -1
    return 'v'
  endif
  if params != -1
    return 'f'
  endif
  return 'm'
endfunction

function! s:DemangleProto(prototype)
  let proto = substitute(a:prototype, '[#', '', 'g')
  let proto = substitute(proto, '#]', ' ', 'g')
  let proto = substitute(proto, '#>', '', 'g')
  let proto = substitute(proto, '<#', '', 'g')
  let proto = substitute(proto, '{#.*#}', '', 'g')
  return proto
endfunction

function! neocomplcache#sources#clang_complete#define()
  return s:source
endfunction

" vim: expandtab:ts=2:sts=2:sw=2
