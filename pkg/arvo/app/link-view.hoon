::  link-view: frontend endpoints
::
::  endpoints, mapping onto link-store's paths. p is for page as in pagination.
::  only the /0/submissions endpoint provides updates.
::  as with link-store, urls are expected to use +wood encoding.
::
::    /json/0/submissions                             initial + updates for all
::    /json/[p]/submissions/[collection]              page for one collection
::    /json/[p]/discussions/[wood-url]/[collection]   page for url in collection
::    /json/[n]/submission/[wood-url]/[collection]    nth matching submission
::    /json/seen                                      mark-as-read updates
::
/-  *link, view=link-view
/-  *invite-store, group-store
/-  listen-hook=link-listen-hook
/-  group-hook, permission-hook, permission-group-hook
/-  metadata-hook, contact-view
/+  store=link-store, metadata, *server, default-agent, verb, dbug
~%  %link-view-top  ..is  ~
::
|%
+$  versioned-state
  $%  state-0
      state-1
  ==
+$  state-0
  $:  %0
      ~
  ==
::
+$  state-1
  $:  %1
      ~
  ==
::
+$  card  card:agent:gall
--
::
=|  state-1
=*  state  -
::
%+  verb  |
%-  agent:dbug
^-  agent:gall
=<
  |_  =bowl:gall
  +*  this  .
      do    ~(. +> bowl)
      def   ~(. (default-agent this %|) bowl)
  ::
  ++  on-init
    ^-  (quip card _this)
    :_  this
    :~  [%pass /submissions %agent [our.bowl %link-store] %watch /submissions]
        [%pass /discussions %agent [our.bowl %link-store] %watch /discussions]
        [%pass /seen %agent [our.bowl %link-store] %watch /seen]
      ::
        =+  [%invite-action !>([%create /link])]
        [%pass /invitatory/create %agent [our.bowl %invite-store] %poke -]
      ::
        =+  /invitatory/link
        [%pass - %agent [our.bowl %invite-store] %watch -]
        :*  %pass  /srv  %agent  [our.bowl %file-server]
            %poke  %file-server-action
            !>([%serve-dir /'~link' /app/landscape %.n])
        ==
    ==
  ::
  ++  on-save  !>(state)
  ++  on-load
    |=  old-vase=vase
    ^-  (quip card _this)
    =/  old  !<(versioned-state old-vase)
    ?-  -.old
        %1  [~ this]
        %0
      :_  this(state [%1 ~])
      :-  [%pass /connect %arvo %e %disconnect [~ /'~link']]
      :~  :*  %pass  /srv  %agent  [our.bowl %file-server]
          %poke  %file-server-action
          !>([%serve-dir /'~link' /app/landscape %.n])
      ==  ==
    ==
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    ?>  (team:title our.bowl src.bowl)
    :_  this
    ?+  mark  (on-poke:def mark vase)
        %link-action
      [(handle-action:do !<(action:store vase)) ~]
    ::
        %link-view-action
      (handle-view-action:do !<(action:view vase))
    ==
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card _this)
    ?:  ?=([%json %seen ~] path)
      [~ this]
    ?:  ?=([%tile ~] path)
      :_  this
      ~[give-tile-data:do]
    ?.  ?=([%json @ @ *] path)
      (on-watch:def path)
    =/  p=@ud  (slav %ud i.t.path)
    ?+  t.t.path  (on-watch:def path)
        [%submissions ~]
      :_  this
      (give-initial-submissions:do p ~)
    ::
        [%submissions ^]
      :_  this
      (give-initial-submissions:do p t.t.t.path)
    ::
        [%submission @ ^]
      :_  this
      (give-specific-submission:do p (break-discussion-path:store t.t.t.path))
    ::
        [%discussions @ ^]
      :_  this
      (give-initial-discussions:do p (break-discussion-path:store t.t.t.path))
    ==
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    ?+  -.sign  (on-agent:def wire sign)
        %kick
      :_  this
      =/  app=term
        ?:  ?=([%invites *] wire)
          %invite-store
        %link-store
      [%pass wire %agent [our.bowl app] %watch wire]~
    ::
        %fact
      =*  mark  p.cage.sign
      =*  vase  q.cage.sign
      ?+  mark  (on-agent:def wire sign)
        %invite-update  [(handle-invite-update:do !<(invite-update vase)) this]
        %link-initial   [~ this]
      ::
          %link-update
        :_  this
        :-  (send-update:do !<(update:store vase))
        ?:  =(/discussions wire)  ~
        ~[give-tile-data:do]
      ==
    ==
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    ?.  ?=([%e %bound *] sign-arvo)
      (on-arvo:def wire sign-arvo)
    ~?  !accepted.sign-arvo
      [dap.bowl "bind rejected!" binding.sign-arvo]
    [~ this]
  ::
  ++  on-peek   on-peek:def
  ++  on-leave  on-leave:def
  ++  on-fail   on-fail:def
  --
::
~%  %link-view-logic  ..card  ~
|_  =bowl:gall
+*  md  ~(. metadata bowl)
::
++  page-size  25
++  get-paginated
  |*  [page=(unit @ud) list=(list)]
  ^-  [total=@ud pages=@ud page=_list]
  =/  l=@ud  (lent list)
  :+  l
    %+  add  (div l page-size)
    (min 1 (mod l page-size))
  ?~  page  list
  %+  swag
    [(mul u.page page-size) page-size]
  list
::
++  page-to-json
  =,  enjs:format
  |*  $:  page-number=@ud
          [total-items=@ud total-pages=@ud page=(list)]
          item-to-json=$-(* json)
      ==
  ^-  json
  %-  pairs
  :~  'totalItems'^(numb total-items)
      'totalPages'^(numb total-pages)
      'pageNumber'^(numb page-number)
      'page'^a+(turn page item-to-json)
  ==
++  do-poke
  |=  [app=term =mark =vase]
  ^-  card
  [%pass /create/[app]/[mark] %agent [our.bowl app] %poke mark vase]
::
++  handle-invite-update
  |=  upd=invite-update
  ^-  (list card)
  ?.  ?=(%accepted -.upd)  ~
  ?.  =(/link path.upd)    ~
  :~  ::  sync the group
      ::
      %^  do-poke  %group-hook
        %group-hook-action
      !>  ^-  group-hook-action:group-hook
      [%add ship path]:invite.upd
    ::
      ::  sync the metadata
      ::
      %^  do-poke  %metadata-hook
        %metadata-hook-action
      !>  ^-  metadata-hook-action:metadata-hook
      [%add-synced ship path]:invite.upd
  ==
::
++  handle-action
  |=  =action:store
  ^-  card
  [%pass /action %agent [our.bowl %link-store] %poke %link-action !>(action)]
::
++  handle-view-action
  |=  act=action:view
  ^-  (list card)
  ?-  -.act
    %create  (handle-create +.act)
    %delete  (handle-delete +.act)
    %invite  (handle-invite +.act)
  ==
::
++  handle-create
  |=  [=path title=@t description=@t members=create-members:view real-group=?]
  ^-  (list card)
  =/  group-path=^path
    ?-  -.members
      %group  path.members
    ::
        %ships
      %+  weld
        ?:(real-group ~ [~.~]~)
      [(scot %p our.bowl) path]
    ==
  =;  group-setup=(list card)
    %+  weld  group-setup
    :~  ::  add collection to metadata-store
        ::
        %^  do-poke  %metadata-hook
          %metadata-action
        !>  ^-  metadata-action:md
        :^  %add  group-path
          [%link path]
        %*  .  *metadata:md
          title         title
          description   description
          date-created  now.bowl
          creator       our.bowl
        ==
      ::
        ::  expose the metadata
        ::
        %^  do-poke  %metadata-hook
          %metadata-hook-action
        !>  ^-  metadata-hook-action:metadata-hook
        [%add-owned group-path]
      ::
        ::  watch the collection ourselves
        ::
        %^  do-poke  %link-listen-hook
          %link-listen-action
        !>  ^-  action:listen-hook
        [%watch path]
    ==
  ?:  ?=(%group -.members)  ~
  ::  if the group is "real", make contact-view do the heavy lifting
  ::
  ?:  real-group
    :_  ~
    %^  do-poke  %contact-view
      %contact-view-action
    !>  ^-  contact-view-action:contact-view
    [%create group-path ships.members title description]
  ::  for "unmanaged" groups, do it ourselves
  ::
  :*  ::  create the new group
      ::
      %^  do-poke  %group-store
        %group-action
      !>  ^-  group-action:group-store
      [%bundle group-path]
    ::
      ::  fill the new group
      ::
      %^  do-poke  %group-store
        %group-action
      !>  ^-  group-action:group-store
      [%add (~(put in ships.members) our.bowl) group-path]
    ::
      ::  make group available
      ::
      %^  do-poke  %group-hook
        %group-hook-action
      !>  ^-  group-hook-action:group-hook
      [%add our.bowl group-path]
    ::
      ::  mirror group into a permission
      ::
      %^  do-poke  %permission-group-hook
        %permission-group-hook-action
      !>  ^-  permission-group-hook-action:permission-group-hook
      [%associate group-path [group-path^%white ~ ~]]
    ::
      ::  expose the permission
      ::
      %^  do-poke  %permission-hook
        %permission-hook-action
      !>  ^-  permission-hook-action:permission-hook
      [%add-owned group-path group-path]
    ::
      ::  send invites
      ::
      %+  turn  ~(tap in ships.members)
      |=  =ship
      ^-  card
      %^  do-poke  %invite-hook
        %invite-action
      !>  ^-  invite-action
      :^  %invite  /link
        (sham group-path eny.bowl)
      :*  our.bowl
          %group-hook
          group-path
          ship
          title
      ==
  ==
::
++  handle-delete
  |=  =path
  ^-  (list card)
  =/  groups=(list ^path)
    (groups-from-resource:md [%link path])
  %-  zing
  %+  turn  groups
  |=  =group=^path
  %+  snoc
    ^-  (list card)
    ::  if it's a real group, we can't/shouldn't unsync it. this leaves us with
    ::  no way to stop propagation of collection deletion.
    ::
    ?.  ?=([%'~' ^] group-path)  ~
    ::  if it's an unmanaged group, we just stop syncing the group & metadata,
    ::  and clean up the group (after un-hooking it, to not push deletion).
    ::
    :~  %^  do-poke  %group-hook
          %group-hook-action
        !>  ^-  group-hook-action:group-hook
        [%remove group-path]
      ::
        %^  do-poke  %metadata-hook
          %metadata-hook-action
        !>  ^-  metadata-hook-action:metadata-hook
        [%remove group-path]
      ::
        %^  do-poke  %group-store
          %group-action
        !>  ^-  group-action:group-store
        [%unbundle group-path]
    ==
  ::  remove collection from metadata-store
  ::
  %^  do-poke  %metadata-store
    %metadata-action
  !>  ^-  metadata-action:md
  [%remove group-path [%link path]]
::
++  handle-invite
  |=  [=path ships=(set ship)]
  ^-  (list card)
  %-  zing
  %+  turn  (groups-from-resource:md %link path)
  |=  =group=^path
  ^-  (list card)
  :-  %^  do-poke  %group-store
        %group-action
      !>  ^-  group-action:group-store
      [%add ships group-path]
  ::  for managed groups, rely purely on group logic for invites
  ::
  ?.  ?=([%'~' ^] group-path)
    ~
  ::  for unmanaged groups, send invites manually
  ::
  %+  turn  ~(tap in ships)
  |=  =ship
  ^-  card
  %^  do-poke  %invite-hook
    %invite-action
  !>  ^-  invite-action
  :^  %invite  /link
    (sham group-path eny.bowl)
  :*  our.bowl
      %group-hook
      group-path
      ship
      (rsh 3 1 (spat path))
  ==
::  +give-tile-data: total unread count as json object
::
::NOTE  the full recalc of totals here probably isn't the end of the world.
::      but in case it is, well, here it is.
::
++  give-tile-data
  ^-  card
  =;  =json
    [%give %fact ~[/tile] %json !>(json)]
  %+  frond:enjs:format  'unseen'
  %-  numb:enjs:format
  %-  %~  rep  in
      (scry-for (jug path url) /unseen)
  |=  [[=path unseen=(set url)] total=@ud]
  %+  add  total
  ~(wyt in unseen)
::
::  +give-initial-submissions: page of submissions on path
::
::    for the / path, give page for every path
::
::    result is in the shape of: {
::      "/some/path": {
::        totalItems: 1,
::        totalPages: 1,
::        pageNumber: 0,
::        page: [
::          { commentCount: 1, ...restOfTheSubmission }
::        ]
::      },
::      "/maybe/more": { etc }
::    }
::
++  give-initial-submissions
  ~/  %link-view-initial-submissions
  |=  [p=@ud =requested=path]
  ^-  (list card)
  :_  ::  only keep the base case alive (for updates), kick all others
      ::
      ?:  &(=(0 p) ?=(~ requested-path))  ~
      [%give %kick ~ ~]~
  =;  =json
    [%give %fact ~ %json !>(json)]
  %+  frond:enjs:format  'link-update'
  %+  frond:enjs:format  'initial-submissions'
  %-  pairs:enjs:format
  %+  turn
    %~  tap  by
    %+  scry-for  (map path submissions)
    [%submissions requested-path]
  |=  [=path =submissions]
  ^-  [@t json]
  :-  (spat path)
  =;  =json
    ::  add unseen count
    ::
    ?>  ?=(%o -.json)
    :-  %o
    %+  ~(put by p.json)  'unseenCount'
    %-  numb:enjs:format
    %~  wyt  in
    %+  scry-for  (set url)
    [%unseen path]
  ?:  &(=(0 p) ?=(~ requested-path))
    ::  for a broad-scope initial result, only give total counts
    ::
    =,  enjs:format
    %-  pairs
    =+  l=(lent submissions)
    :~  'totalItems'^(numb l)
        'totalPages'^(numb (div l page-size))
    ==
  %^  page-to-json  p
    %+  get-paginated  `p
    submissions
  |=  =submission
  ^-  json
  =/  =json  (submission:enjs:store submission)
  ?>  ?=([%o *] json)
  ::  add in seen status
  ::
  =.  p.json
    %+  ~(put by p.json)  'seen'
    :-  %b
    %+  scry-for  ?
    [%seen (build-discussion-path:store path url.submission)]
  ::  add in comment count
  ::
  =;  comment-count=@ud
    :-  %o
    %+  ~(put by p.json)  'commentCount'
    (numb:enjs:format comment-count)
  %-  lent
  ~|  [path url.submission]
  ^-  comments
  =-  (~(got by (~(got by -) path)) url.submission)
  %+  scry-for  (per-path-url comments)
  :-  %discussions
  (build-discussion-path:store path url.submission)
::
++  give-specific-submission
  |=  [n=@ud =path =url]
  :_  [%give %kick ~ ~]~
  =;  =json
    [%give %fact ~ %json !>(json)]
  %+  frond:enjs:format  'link-update'
  %+  frond:enjs:format  'submission'
  ^-  json
  =;  sub=(unit submission)
    ?~  sub  ~
    (submission:enjs:store u.sub)
  =/  =submissions
    =-  (~(got by -) path)
    %+  scry-for  (map ^path submissions)
    [%submissions path]
  |-
  ?~  submissions  ~
  =*  sub  i.submissions
  ?.  =(url.sub url)
    $(submissions t.submissions)
  ?:  =(0 n)  `sub
  $(n (dec n), submissions t.submissions)
::
++  give-initial-discussions
  |=  [p=@ud =path =url]
  ^-  (list card)
  :_  ?:  =(0 p)  ~
      [%give %kick ~ ~]~
  =;  =json
    [%give %fact ~ %json !>(json)]
  %+  frond:enjs:format  'link-update'
  %+  frond:enjs:format  'initial-discussions'
  %^  page-to-json  p
    %+  get-paginated  `p
    =-  (~(got by (~(got by -) path)) url)
    %+  scry-for  (per-path-url comments)
    [%discussions (build-discussion-path:store path url)]
  comment:enjs:store
::
++  send-update
  |=  =update:store
  ^-  card
  ?+  -.update  ~|([dap.bowl %unexpected-update -.update] !!)
      %submissions
    %+  give-json
      %+  frond:enjs:format  'link-update'
      (update:enjs:store update)
    :~  /json/0/submissions
        (weld /json/0/submissions path.update)
    ==
  ::
      %discussions
    %+  give-json
      %+  frond:enjs:format  'link-update'
      (update:enjs:store update)
    :_  ~
    %+  weld  /json/0/discussions
    (build-discussion-path:store [path url]:update)
  ::
      %observation
    %+  give-json
      %+  frond:enjs:format  'link-update'
      (update:enjs:store update)
    ~[/json/seen]
  ==
::
++  give-json
  |=  [=json paths=(list path)]
  ^-  card
  [%give %fact paths %json !>(json)]
::
++  scry-for
  |*  [=mold =path]
  .^  mold
    %gx
    (scot %p our.bowl)
    %link-store
    (scot %da now.bowl)
    (snoc `^path`path %noun)
  ==
--
