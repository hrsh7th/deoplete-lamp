let s:Promise = vital#lamp#import('Async.Promise')

let s:request = {}

"
" deoplete_lamp#clear
"
function! deoplete_lamp#clear() abort
  let s:request = {}
endfunction

"
" deoplete_lamp#get_servers
"
function! deoplete_lamp#get_servers() abort
  let l:servers = lamp#server#registry#find_by_filetype(&filetype)
  let l:servers = filter(l:servers, { k, v -> v.supports('capabilities.completionProvider') })
  return l:servers
endfunction

"
" deoplete_lamp#is_completable
"
function! deoplete_lamp#is_completable() abort
  let l:servers = deoplete_lamp#get_servers()
  let l:chars = []
  for l:server in l:servers
    let l:chars += l:server.capability.get_completion_trigger_characters()
  endfor


  " before char is trigger character.
  if index(l:chars, lamp#view#cursor#get_before_char_skip_white()) >= 0
    return v:true
  endif

  " input keyword.
  let l:before_line  = lamp#view#cursor#get_before_line()
  let l:match = strlen(matchstr(l:before_line, s:create_regex() . '$')) >= 1
  if l:match
    return v:true
  endif

  return v:false
endfunction

"
" deoplete_lamp#find_request
"
function! deoplete_lamp#find_request(...)
  if mode()[0] !=# 'i'
    return
  endif

  if empty(s:request)
    return v:null
  endif

  let l:position = s:get_complete_position()
  if s:request.position.line == l:position.line && s:request.position.character == l:position.character
    return s:request
  endif

  return v:null
endfunction

"
" deoplete_lamp#request
"
function! deoplete_lamp#request()
  if mode()[0] !=# 'i'
    return
  endif

  let l:position = s:get_complete_position()

  " skip request if match current context
  if !empty(deoplete_lamp#find_request(l:position))
    return
  endif

  " request completion
  let s:request = {
        \   'position': l:position,
        \   'responses': []
        \ }

  let l:promises = map(deoplete_lamp#get_servers(), { k, v ->
        \   v.request('textDocument/completion', {
        \     'textDocument': lamp#protocol#document#identifier(bufnr('%')),
        \     'position': l:position,
        \     'context': {
        \       'triggerKind': 2,
        \       'triggerCharacter': lamp#view#cursor#get_before_char_skip_white()
        \     }
        \   }).then({ response -> { 'server_name': v.name, 'data': response } }).catch(lamp#rescue({ 'server_name': v.name, 'data': [] }))
        \ })

  let l:p = s:Promise.all(l:promises)
  let l:p = l:p.then({ responses -> s:on_responses(l:position, responses) })
  let l:p = l:p.catch(lamp#rescue())
endfunction

"
" on_responses
"
function! s:on_responses(position, responses)
  let l:request = deoplete_lamp#find_request(a:position)
  if empty(l:request)
    return
  endif

  let l:request.responses = a:responses
  call deoplete#auto_complete()
endfunction

"
" create_regex
"
function! s:create_regex() abort
  let l:keywords = split(&iskeyword, ',')
  let l:keywords = filter(l:keywords, { _, k -> match(k, '\d\+-\d\+') == -1 })
  let l:keywords = filter(l:keywords, { _, k -> k !=# '@' })
  let l:pattern = '\%(' . join(map(l:keywords, { _, v -> '\V' . escape(v, '\') . '\m' }), '\|') . '\|\w\|\d\)'
  return l:pattern
endfunction

"
" get_complete_position
"
function! s:get_complete_position() abort
  let l:servers = deoplete_lamp#get_servers()
  let l:chars = []
  for l:server in l:servers
    let l:chars += l:server.capability.get_completion_trigger_characters()
  endfor

  let l:position = lamp#protocol#position#get()
  let l:before_line = substitute(lamp#view#cursor#get_before_line(), '\w*$', '', 'g')
  let l:position.character = strlen(l:before_line)
  if index(l:chars, l:before_line[-1 : -1]) == -1
    let l:position.character += 1
  endif
  return l:position
endfunction
