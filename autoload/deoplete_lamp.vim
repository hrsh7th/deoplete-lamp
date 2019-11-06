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
  return strlen(matchstr(l:before_line, '\k*$')) >= 1
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

  let l:position = get(a:000, 0, lamp#protocol#position#get())
  if s:request.position.line == l:position.line && s:request.position.character == l:position.character
    return s:request
  endif

  let l:before_line  = lamp#view#cursor#get_before_line()
  if strlen(matchstr(l:before_line, '\k*$')) > 1
    return s:request
  endif
  return v:null
endfunction

"
" request.
"
function! deoplete_lamp#request()
  if mode()[0] !=# 'i'
    return
  endif

  let l:position = lamp#protocol#position#get()

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
" s:on_responses
"
function! s:on_responses(position, responses)
  let l:request = deoplete_lamp#find_request(a:position)
  if empty(l:request)
    return
  endif

  let l:request.responses = a:responses
  if mode()[0] ==# 'i'
    call deoplete#auto_complete()
  endif
endfunction

