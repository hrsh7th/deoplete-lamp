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

  let l:text = getline(l:position.line + 1)[0 : l:position.character]
  if matchstr(l:text, '\k*$') !=# ''
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
        \   'responses': v:null
        \ }

  let l:promises = map(deoplete_lamp#get_servers(), { k, v ->
        \   v.request('textDocument/completion', {
        \     'textDocument': lamp#protocol#document#identifier(bufnr('%')),
        \     'position': l:position,
        \     'context': {
        \       'triggerKind': 2
        \     }
        \   }).then({ response -> { 'server': v, 'data': response } }).catch(lamp#rescue({ 'server': v, 'data': [] }))
        \ })

  call s:Promise.all(l:promises).then(function('s:on_response', [l:position]))
endfunction

"
" s:on_response
"
function! s:on_response(position, responses)
  let l:request = deoplete_lamp#find_request(a:position)
  if empty(l:request)
    return
  endif

  let l:request.responses = s:normalize(a:responses)
  if mode()[0] ==# 'i'
    call deoplete#auto_complete()
  endif
endfunction

"
" s:normalize
"
function! s:normalize(responses) abort
  let l:results = []
  for l:response in a:responses
    call add(l:results, {
          \   'server_name': l:response['server']['name'],
          \   'isIncomplete': get(l:response['data'], 'isIncomplete', v:false),
          \   'items': type(l:response['data']) == type([]) ? l:response['data'] : get(l:response['data'], 'items', [])
          \ })
  endfor
  return l:results
endfunction

