" Vim global plugin for autoloading cscope databases.
" Save this file as ~/.vim/plugin/autoload_cscope.vim present
" so you can invoke vim in subdirectories and still get cscope.out loaded.
" Last Change: Wed Jan 26 10:28:52 Jerusalem Standard Time 2011
" Maintainer: Michael Conrad Tadpol Tilsra <tadpol@tadpol.org>
" Revision: 0.5 (plus the below)
" With additions from ckelau & ufengzh for .cpp suffix files
" With additions from Code-Monky & ckelau for .java suffix files
" See pull requests at https://github.com/vim-scripts/autoload_cscope.vim
" With additions from Jason Duell's cscope settings by Dan Nygren
" With additions for .hpp suffix files by Dan Nygren


""""""""""""" Jason Duell's cscope/vim key mappings
" (From http://cscope.sourceforge.net/cscope_maps.vim with light edits. )
" The following maps all invoke one of the following cscope search types:
"
"   's'   symbol: find all references to the token under cursor
"   'g'   global: find global definition(s) of the token under cursor
"   'c'   calls:  find all calls to the function name under cursor
"   't'   text:   find all instances of the text under cursor
"   'e'   egrep:  egrep search for the word under cursor
"   'f'   file:   open the filename under cursor
"   'i'   includes: find files that include the filename under cursor
"   'd'   called: find functions that function under cursor calls
"
" Below are the maps: one set that just jumps to your search result, and one
" that splits the existing vim window horizontally and displays your search
" result in the new window.
"
" I've used CTRL-\ and CTRL-_ as the starting keys for these maps, as it's
" unlikely that you need their default mappings.
"
" To do the first type of search, hit 'CTRL-\', followed by one of the
" cscope search types above (s,g,c,t,e,f,i,d).  The result of your cscope
" search will be displayed in the current window.  You can use CTRL-T to
" go back to where you were before the search.
"

if exists("loaded_autoload_cscope")
	finish
endif
let loaded_autoload_cscope = 1

" requirements, you must have these enabled or this is useless.
if(  !has('cscope') || !has('modify_fname') )
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

" If you set this to anything other than 1, the menu and macros will not be
" loaded.  Useful if you have your own that you like.  Or don't want my stuff
" clashing with any macros you've made.
if !exists("g:autocscope_menus")
  let g:autocscope_menus = 1
endif

"==
" windowdir
"  Gets the directory for the file in the current window
"  Or the current working dir if there isn't one for the window.
"  Use tr to allow that other OS paths, too
function s:windowdir()
  if winbufnr(0) == -1
    let unislash = getcwd()
  else 
    let unislash = fnamemodify(bufname(winbufnr(0)), ':p:h')
  endif
    return tr(unislash, '\', '/')
endfunc
"
"==
" Find_in_parent
" find the file argument and returns the path to it.
" Starting with the current working dir, it walks up the parent folders
" until it finds the file, or it hits the stop dir.
" If it doesn't find it, it returns "Nothing"
function s:Find_in_parent(fln,flsrt,flstp)
  let here = a:flsrt
  while ( strlen( here) > 0 )
    if filereadable( here . "/" . a:fln )
      return here
    endif
    let fr = match(here, "/[^/]*$")
    if fr == -1
      break
    endif
    let here = strpart(here, 0, fr)
    if here == a:flstp
      break
    endif
  endwhile
  return "Nothing"
endfunc
"
"==
" Cycle_macros_menus
"  if there are cscope connections, activate that stuff.
"  Else toss it out.
"  TODO Maybe I should move this into a separate plugin?
let s:menus_loaded = 0
function s:Cycle_macros_menus()
  if g:autocscope_menus != 1
    return
  endif
  if cscope_connection()
    if s:menus_loaded == 1
      return
    endif
    let s:menus_loaded = 1
    set csto=0
    set cst
    silent! map <unique> <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>
" cscope's global function definition search does not work with
" '__attribute__((unused))' in function definitions because cscope
" cannot tolerate arbitrary use of () characters in the argument list.
" (Dan Nygren)
    silent! map <unique> <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>f :cs find f <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>i :cs find i <C-R>=expand("<cword>")<CR><CR>
" Addition from Jason Duell's cscope settings (Dan Nygren)
" Split screen horizontally with CTRL underscore
    silent! map <unique> <C-_>s :scs find s <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>g :scs find g <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>c :scs find c <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>t :scs find t <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>e :scs find e <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>f :scs find f <C-R>=expand("<cfile>")<CR><CR>
    silent! map <unique> <C-_>i :scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
    silent! map <unique> <C-_>d :scs find d <C-R>=expand("<cword>")<CR><CR>
" End Split screen horizontally
    if has("menu")
      nmenu &Cscope.Find.Symbol<Tab><c-\\>s
        \ :cs find s <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.Definition<Tab><c-\\>g
        \ :cs find g <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.Called<Tab><c-\\>d
        \ :cs find d <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.Calling<Tab><c-\\>c
        \ :cs find c <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.Assignment<Tab><c-\\>t
        \ :cs find t <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.Egrep<Tab><c-\\>e
        \ :cs find e <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.File<Tab><c-\\>f
        \ :cs find f <C-R>=expand("<cword>")<CR><CR>
      nmenu &Cscope.Find.Including<Tab><c-\\>i
        \ :cs find i <C-R>=expand("<cword>")<CR><CR>
"      nmenu &Cscope.Add :cs add 
"      nmenu &Cscope.Remove  :cs kill 
      nmenu &Cscope.Reset :cs reset<cr>
      nmenu &Cscope.Show :cs show<cr>
      " Need to figure out how to do the add/remove. May end up writing
      " some container functions.  Or tossing them out, since this is supposed
      " to all be automatic.
    endif
  else
    let s:menus_loaded = 0
    set nocst
    silent! unmap <C-\>s
    silent! unmap <C-\>g
    silent! unmap <C-\>d
    silent! unmap <C-\>c
    silent! unmap <C-\>t
    silent! unmap <C-\>e
    silent! unmap <C-\>f
    silent! unmap <C-\>i
    if has("menu")  " would rather see if the menu exists, then remove...
      silent! nunmenu Cscope
    endif
  endif
endfunc
"
"==
" Unload_csdb
"  drop cscope connections.
function s:Unload_csdb()
  if exists("b:csdbpath")
    if cscope_connection(3, "out", b:csdbpath)
      let save_csvb = &csverb
      set nocsverb
      exe "cs kill " . b:csdbpath
      set csverb
      let &csverb = save_csvb
    endif
  endif
endfunc
"
"==
" Cycle_csdb
"  cycle the loaded cscope db.
function s:Cycle_csdb()
    if exists("b:csdbpath")
      if cscope_connection(3, "out", b:csdbpath)
        return
        "it is already loaded. don't try to reload it.
      endif
    endif
    let newcsdbpath = s:Find_in_parent("cscope.out",s:windowdir(),$HOME)
"    echo "Found cscope.out at: " . newcsdbpath
"    echo "Windowdir: " . s:windowdir()
    if newcsdbpath != "Nothing"
      let b:csdbpath = newcsdbpath
      if !cscope_connection(3, "out", b:csdbpath)
        let save_csvb = &csverb
        set nocsverb
        exe "cs add " . b:csdbpath . "/cscope.out " . b:csdbpath
        set csverb
        let &csverb = save_csvb
      endif
      "
    else " No cscope database, undo things. (someone rm-ed it or somesuch)
      call s:Unload_csdb()
    endif
endfunc

" By default, cscope examines C (.c & .h), lex (.l), and yacc (.y) source files.
" Additions made for C++ source files (.cc, .cpp, .hpp).
" Additions made for Java source files (.java).
" auto toggle the menu
augroup autoload_cscope
 au!
 au BufEnter *.[chly]  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.cc      call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.[ch]pp  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.java  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.[chly] call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.cc     call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.[ch]pp  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.java  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
augroup END

let &cpo = s:save_cpo

" Addition from Jason Duell's cscope settings
"    """"""""""""" key map timeouts
"    "
"    " By default Vim will only wait 1 second for each keystroke in a mapping.
"    " You may find that too short with the above typemaps.  If so, you should
"    " either turn off mapping timeouts via 'notimeout'.
"    "
"    "set notimeout
"    "
"    " Or, you can keep timeouts, by uncommenting the timeoutlen line below,
"    " with your own personal favorite value (in milliseconds):
"    "
"    "set timeoutlen=4000
set timeoutlen=2000
"    "
"    " Either way, since mapping timeout settings by default also set the
"    " timeouts for multicharacter 'keys codes' (like <F1>), you should also
"    " set ttimeout and ttimeoutlen: otherwise, you will experience strange
"    " delays as vim waits for a keystroke after you hit ESC (it will be
"    " waiting to see if the ESC is actually part of a key code like <F1>).
"    "
"    "set ttimeout
set ttimeout
"    "
"    " personally, I find a tenth of a second to work well for key code
"    " timeouts. If you experience problems and have a slow terminal or network
"    " connection, set it higher.  If you don't set ttimeoutlen, the value for
"    " timeoutlent (default: 1000 = 1 second, which is sluggish) is used.
"    "
"    "set ttimeoutlen=100
set ttimeoutlen=100
"
