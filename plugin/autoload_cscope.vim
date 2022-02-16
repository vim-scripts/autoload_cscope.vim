""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" autoload_cscope.vim: Vim global plugin for autoloading Cscope databases
"
" Based on revision: 0.5 of autoload_cscope.vim by Michael Conrad Tadpol Tilsra
" https://www.vim.org/scripts/script.php?script_id=157
" With additions from Jason Duell's cscope_macros.vim 2.0.0
" https://www.vim.org/scripts/script.php?script_id=51
" http://cscope.sourceforge.net/cscope_maps.vim
" With additions from ckelau & ufengzh for .cpp suffix files
" With additions from Code-Monky & ckelau for .java suffix files
" With additions for .hpp suffix files by Dan Nygren
" With additions for Python and Go by xin3liang
" See pull requests at https://github.com/vim-scripts/autoload_cscope.vim
" With additions for automatically updating cscope database after saves by Flynn
" https://vim.fandom.com/wiki/Script:157
" CC BY-SA license
"
" Combined by: Dan Nygren
" Email: nygren@msss.com
" Permanent Email: dan.nygren@gmail.com
" Copyright (c) 2022 Dan Nygren.
" BSD 0-clause license, "Zero Clause BSD", SPDX: 0BSD
"
"   Save this file as ~/.vim/plugin/autoload_cscope.vim so you can invoke
" vim/gvim in subdirectories and still get cscope.out loaded. It performs a
" search starting at the directory that the edited file is in, checking the
" parent directories until it finds the cscope.out file. Therefore you can
" start editing a file deep in a project directory, and it will find the
" correct Cscope database.
"   A prerequisite for use is that a Cscope database has been generated. Cscope
" can be executed on the command line, or a script like cscope_db_gen can be
" used to generate the database. See https://github.com/dnygren/cscope_db_gen
" for an example of how to generate a Cscope database for C/C++.
"   This plugin also adds a Cscope selection to gvim's menu bar.
"
" CALL SEQUENCE  Place in  ~/.vim/plugin directory to call
"
" EXAMPLES       N/A
"
" TARGET SYSTEM  Unix vim / gvim
"
" DEVELOPED ON   Linux
"
" CALLS          cscope, cscope_db_gen
"
" CALLED BY      vim / gvim
"
" INPUTS         autocscope_auto_update, loaded_autoload_cscope
"
" OUTPUTS        (Parameters modified, include global/static data)
"
" RETURNS        (Type and meaning of return value, if any)
"
" ERROR HANDLING (Describe how errors are handled)
"
" SECURE CODING  (List methods used to prevent exploits against this code)
"
" WARNINGS       1) A Cscope database must exist in a parent directory.
"                2) Cscope's global function definition search does not work
"                with '__attribute__((unused))' in function definitions because
"                Cscope cannot tolerate arbitrary use of () characters in the
"                argument list.
"                (N. Describe anything a maintainer should be aware of)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""" Jason Duell's Cscope/Vim Key Mappings Cheat Sheet """""""""""""""
" (From http://cscope.sourceforge.net/cscope_maps.vim with light edits. )
" The following maps all invoke one of the following Cscope search types:
"
"   's'   symbol:   find all references to the token under cursor
"   'g'   global:   find global definition(s) of the token under cursor
"   'c'   calls:    find all calls to the function name under cursor
"   't'   text:     find all instances of the text under cursor
"   'e'   egrep:    egrep search for the word under cursor
"   'f'   file:     open the filename under cursor
"   'i'   includes: find files that include the filename under cursor
"   'd'   called:   find functions that function under cursor calls
"
" The starting keys for the searches are:
" CTRL-\ (Control Backslash) which just jumps to your search result,
" CTRL-_ (Control Underscore, i.e. CTRL-Shift-Dash) splits the Vim window,
" CTRL-_CTRL-_ (Control Underscore twice) splits the Vim window vertically.
"
" To do the first type of search, hit 'CTRL-\', followed by one of the Cscope
" search types above (s,g,c,t,e,f,i,d). Use CTRL-t to go back to where the
" searching began. The second and third types of search use CTRL-_ and then
" and CTRL-_ twice respectively. The result of your Cscope search will be
" displayed in the current window.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" If this script is already loaded, skip loading the script again.
if exists("loaded_autoload_cscope")
    finish
endif
let loaded_autoload_cscope = 1

" The default Cscope path component (cspc) value of "0" displays the entire
" path, which usually doesn't fit the screen and so gets be abbreviated to just
" the starting path (usually useless) and the ending path (most already known).
" The below construct sets cspc to a more reasonable value if cscp hasn't been
" changed from the default in the user's .vimrc file.
"
if &cspc == "0"
    set cspc=4
endif

" If set to 1, auto update your cscope/gtags database and reset the
" Cscope connection when a file is saved.
if !exists("g:autocscope_auto_update")
  let g:autocscope_auto_update = 1
endif

" If set to 1, the menu and macros will be loaded. Set value something other
" than 1 if they are not wanted.
if !exists("g:autocscope_menus")
  let g:autocscope_menus = 1
endif

" If set to 1, use gtags-cscope which is faster than cscope.
if !exists("g:autocscope_use_gtags")
  let g:autocscope_use_gtags = 0
endif


" ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
" ^^^^^^^^^^ Place code that may need modification above this point. ^^^^^^^^^^
" ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

" Vim must have these enabled or this plugin is useless.
if( !has('cscope') || !has('modify_fname') )
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

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
"  if there are Cscope connections, activate that stuff.
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
" Update the cheat sheet if the mappings are changed.
    silent! map <unique> <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-\>f :cs find f <C-R>=expand("<cfile>")<CR><CR>
    silent! map <unique> <C-\>i :cs find i <C-R>=expand("<cfile>")<CR><CR>
" Split screen horizontally with CTRL underscore (CTRL-Shift-Dash)
    silent! map <unique> <C-_>s :scs find s <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>g :scs find g <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>c :scs find c <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>t :scs find t <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>e :scs find e <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_>f :scs find f <C-R>=expand("<cfile>")<CR><CR>
    silent! map <unique> <C-_>i :scs find i <C-R>=expand("<cfile>")<CR><CR>
    silent! map <unique> <C-_>d :scs find d <C-R>=expand("<cword>")<CR><CR>
" End Split screen horizontally
" Split screen vertically with CTRL underscore twice (CTRL-Shift-Dash twice)
" Line continuation. See :help line-continuation
    silent! map <unique> <C-_><C-_>s
        \    :vert scs find s <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_><C-_>g
        \    :vert scs find g <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_><C-_>c
        \    :vert scs find c <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_><C-_>t
        \    :vert scs find t <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_><C-_>e
        \    :vert scs find e <C-R>=expand("<cword>")<CR><CR>
    silent! map <unique> <C-_><C-_>f
        \    :vert scs find f <C-R>=expand("<cfile>")<CR><CR>
    silent! map <unique> <C-_><C-_>i
        \    :vert scs find i <C-R>=expand("<cfile>")<CR><CR>
    silent! map <unique> <C-_><C-_>d
        \    :vert scs find d <C-R>=expand("<cword>")<CR><CR>
" End Split screen vertically
    if has("menu")
" Line continuation. See :help line-continuation
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
        \ :cs find f <C-R>=expand("<cfile>")<CR><CR>
      nmenu &Cscope.Find.Including<Tab><c-\\>i
        \ :cs find i <C-R>=expand("<cfile>")<CR><CR>
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
"  drop Cscope connections.
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
"  cycle the loaded Cscope db.
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
    else " No Cscope database, undo things. (someone rm-ed it or ...?)
      call s:Unload_csdb()
    endif
endfunc

" If enabled, auto update your cscope/gtags database and reset the Cscope
" connection when a file is saved.
function s:Update_csdb()
    if g:autocscope_auto_update != 1
      return
    endif

    if exists("b:csdbpath")
      if cscope_connection(3, g:autocscope_tagfile_name, b:csdbpath)
          if g:autocscope_use_gtags == 1
              "exe "silent !cd " . b:csdbpath . " && global -u"
              exe "silent !cd " . b:csdbpath . " && global -u"
" Cscope only examines C (.c & .h), lex (.l), and yacc (.y) source files.
"          else
"              "exe "silent !cd " . b:csdbpath . " && cscope -Rbq"
"              exe "silent !cd " . b:csdbpath . " && cscope -Rbq"
"
" The cscope_db_gen script allows source files other than the Cscope defaults
" to be examined by Cscope (C++ files etc.). When called with the -q "quick"
" flag, cscope_db_gen uses the existing cscope.files list of files. So if new
" files are created, cscope_db_gen without flags must be executed in the
" repository's base directory.
          else
              "exe "silent !cd " . b:csdbpath . " && cscope_db_gen -q"
              exe "silent !cd " . b:csdbpath . " && cscope_db_gen -q"
          endif

          set nocsverb
          exe "cs reset"
          set csverb
      endif
  endif
endfunc

" If set to 1, use gtags-cscope which is faster than cscope.
if g:autocscope_use_gtags == 1
    let g:autocscope_tagfile_name = "GTAGS"
    set cscopeprg=gtags-cscope
else
    let g:autocscope_tagfile_name = "cscope.out"
    set cscopeprg=cscope
endif

" By default, Cscope examines C (.c & .h), lex (.l), and yacc (.y) source files.
" Additions made for C++ source files (.cc, .cpp, .hpp).
" Additions made for Java source files (.java).
" auto toggle the menu
augroup autoload_cscope
 au!
 au BufEnter *.[chly]  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.cc      call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.[ch]pp  call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.java    call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.py      call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
 au BufEnter *.go      call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
" Line continuation. See :help line-continuation
 au BufWritePost *.[chly] call <SID>Update_csdb() | call
    \ <SID>Cycle_macros_menus()
 au BufWritePost *.cc     call <SID>Update_csdb() | call
    \ <SID>Cycle_macros_menus()
 au BufWritePost *.[ch]pp call <SID>Update_csdb() | call
    \ <SID>Cycle_macros_menus()
 au BufWritePost *.java   call <SID>Update_csdb() | call
    \ <SID>Cycle_macros_menus()
 au BufWritePost *.py     call <SID>Update_csdb() | call
    \ <SID>Cycle_macros_menus()
 au BufWritePost *.go     call <SID>Update_csdb() | call
    \ <SID>Cycle_macros_menus()
"
 au BufUnload *.[chly] call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.cc     call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.[ch]pp call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.java   call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.py     call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
 au BufUnload *.go     call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
augroup END

let &cpo = s:save_cpo

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
set timeoutlen=3000
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
