globals [
  number                    ;; number of Vertices
  number-workers            ;; number of workers
;  nb-management            ;; number of workers a manager can manage
  manager                   ;; id of the curent turtles's manager
  depth                     ;; depth of the tree
  redo                      ;; for the recursive functions
  nb-ad                     ;; number of workers added (to count iterations)
  nb-del                    ;; number of workers deleted (to count iterations)
  list-tasks                ;; repartition of the tasks   ||   just for the observer ! (don't use to dispatch tasks)
  nb-managers               ;; number of managers
  ratios                    ;; ratio of worker for each task (a list of weights)
  perfect-list-repartition  ;; distribution list ultimately wanted
  error-distribution        ;; |distribution list ultimately wanted - distribution list|
  ratios-tasks              ;; read-from-string ratio of tasks
  number-tasks              ;; number tasks + ratio
  semaphore                 ;; To synchronise error calculations
  berP                      ;; p of bernoulli
  listProbability           ;; [X0,X1,X2,X3,......]  Bernoulli
  listProbability2          ;; probability : item list perfect / count (Voir le doc explicatif)
  error-distribution-random ;; error Bernoulli
  error-distribution-random2;; error Probability
  n-proba                   ;; random index
  ListTasksProbability      ;; List of probabilities (each task has a probability)
  listP
;  nb-tasks       ;;
;  number-added   ;;
;  number-deleted ;;
]

turtles-own [
  task              ;; -1 -> manager, 0 to n -> worker   ||   faire aussi avec les couleurs
  id                ;; id of the Vertices
  ;; info (if we need to minimize the size of data stocked we can remove info and orders and directly consttruct them when needed)
  info-from-childs  ;; info going up the tree (list of lists of int) ( [[a b c ...] [d e f ...] ...] => [a b c ...] : info of child 0 and a : number of workers under child 0 with task 0 )
  info              ;; info of the current vertex (list of int) ( [a b c ...] => a : number of workers under myself )      (sum of info-from-child)
  orders            ;; list of list of int with the repartition of workers for each child (same as info-from-childs)
  orders-received   ;; list of int with the repartition of workers this turtle has to organise
  info-from-childs-new  ;; new : to do it in 2 times => no need of precise order
  orders-received-new
]


;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 1   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


to setup
  clear-all
  set-default-shape turtles "circle"  ;; set Vertices shape
  setup-patches
  set list-tasks [0 0 0 0 0 0 0 0 0 0 0 0 0]
  set perfect-list-repartition [0 0 0 0 0 0 0 0 0 0 0 0 0]
  set listProbability  [0 0 0 0 0 0 0 0 0 0 0 0 0]
  set listProbability2 [0 0 0 0 0 0 0 0 0 0 0 0 0]
  set ListTasksProbability  []
  set semaphore 0
  set berP 0.5
  reset-ticks
end

;; add a new _Vertex_
to add-vertex
  create-new-turtle
  link-new-turtle
  make-tree
  update-depth
  ;; to increment the workers count
  if ((number + nb-management - 2) / nb-management != floor( (number - 1) / nb-management) + 1) [
    set number-workers ( number-workers + 1 )
  ]
  tick
  display-labels
end

;; delete one vertex
to delete-vertex
  if ( number >= 0 ) [
    if ( number > 0 ) [ set number ( number - 1 ) ]
    let tmp 0
    ask turtles with [ id = number ] [
      remove-task task
      set tmp task
      die
    ]
    manager-to-worker? number tmp        ;; if the manager of the curent deleted worker need to replace it (<=> suppression of the manager)
    update-depth
    ;; to decrement the workers count
    if ((number + nb-management - 1) / nb-management != (floor( number / nb-management) + 1) and number-workers > 0) [
      set number-workers ( number-workers - 1 )
    ]
  ]
  tick
  display-labels
end

;; add number-added workers
;; same as add-vertex but with two iterations if the number of workers doesn't increase on the first one
to add-worker                                         ;; one or multiple ticks ???
  if ( nb-ad = 0 ) [ set nb-ad number-added ]
  create-new-turtle
  link-new-turtle
  make-tree
  update-depth
  if ( redo = 0 ) [
    set number-workers ( number-workers + 1 )   ;; not to count two times the same worker
  ]
  if ( redo = 1 ) [
    add-vertex
  ]
  set nb-ad (nb-ad - 1)
  if ( nb-ad > 0 ) [
    add-worker
  ]
  tick
  display-labels
end

;; delete number-deleted workers
to delete-worker
  if ( number >= 0 ) [
    if ( nb-del = 0 ) [ set nb-del number-deleted ]
    if ( number > 0 ) [ set number ( number - 1 ) ]
    let tmp 0
    ask turtles with [ id = number ] [
      remove-task task
      set tmp task
      die
    ]
    manager-to-worker? number tmp
    ;; "+ nb-management" car dans le cas avec nb-management = 2, ça marche pas pour number = 2
    ;; et "+ 1" à droite pour compenser
    ifelse (nb-management = 2)
    [
      if (number / nb-management = floor (number / nb-management)) [ delete-vertex ]
    ]
    [
      if ( (number + nb-management - 2) / nb-management = floor (number / nb-management) + 1 ) [ delete-vertex ]
    ]
    update-depth
    if ( number-workers > 0 ) [ set number-workers ( number-workers - 1 ) ]
    set nb-del (nb-del - 1)
    if ( nb-del > 0 ) [
      delete-worker
    ]
  ]
  tick
  display-labels
end

;; charge the ratios for the tasks
to charge-ratios              ;; one of the two functions is unuseful
  initialize-ratios
end

;; dispatch workers to tasks
to organise
  charge-ratios
  set-perfect-repartition
  err-distribution-random
  random-distribution
  ifelse Run-Random [
  distribute
  random-distribution-2
  ask turtles with [task != -1] [
    if member? task ListTasksProbability [
      create-adaptive-probability id
      set color task-color task
    ]
    update-listTask
  ]
  update-list-tasks
  set error-distribution 0
  ]
  [
  err-distribution-tasks
  ask turtles [ update ]        ;; update each turtle info
  ask turtles [ communicate ]   ;; proceed of the computations and send the info to parents/childs
  ]
  tick    ;; during one turn
  set error-distribution 0
  display-labels

end

;; update List Tasks of turtles
to update-listTask
  if ListTasksProbability = [] [
    set listTasksProbability range length read-from-string ratio-tasks
  ]
  ask turtles with [task != -1] [
    ifelse length ListTasksProbability = 1 or length ListTasksProbability = 0 [
      if length ListTasksProbability = 1 [
      if item task list-tasks != item task perfect-list-repartition [
          set ListTasksProbability  []
      ]
          set ListTasksProbability []
      ]
    ]
    [
    if item task list-tasks = item task perfect-list-repartition
    [
      set ListTasksProbability remove task ListTasksProbability
    ]
  ]
  ]
end

;; Error Loic Distribution
to err-distribution-tasks
  foreach perfect-list-repartition [
    x -> if x != item (position x perfect-list-repartition) list-tasks [
      set error-distribution error-distribution + abs(item (position x perfect-list-repartition) list-tasks - x)
    ]
  ]

  set semaphore 1
end

;; Perfect Distribution
to set-perfect-repartition
  set number-tasks nb-tasks
  set ratios-tasks read-from-string ratio-tasks
  ;show ratios-tasks
  foreach ratios-tasks [
    x -> if x > 1 [set number-tasks (number-tasks + x - 1)]
  ]
  let modu int(number-workers / number-tasks)
  let res 0
  set res number-workers - (int(number-workers / number-tasks) * number-tasks)
  set perfect-list-repartition []
  let i 0
  while [i < 13 ] [
    ifelse i < length read-from-string ratio-tasks [
      set perfect-list-repartition lput (modu * item i read-from-string ratio-tasks)  perfect-list-repartition
      if i < res [
        set perfect-list-repartition replace-item i perfect-list-repartition ((item i perfect-list-repartition) + 1)
      ]
    ][
      set perfect-list-repartition lput 0 perfect-list-repartition
    ]
    set i i + 1
  ]
end

;; Bernoulli Distribution
to random-distribution
  let curs 0
  let sumP 0
  foreach perfect-list-repartition [
    x -> ifelse curs < 12 [
      if item curs listProbability != x [
        bernoulli x curs
      ]
      set sumP sumP + item curs listProbability
    ]
    [
      set listProbability replace-item 12 listProbability (number-workers - sumP)
    ]
   set curs curs + 1
  ]
end

;; Error of random Distribution
to err-distribution-random
  let curs 0
  set error-distribution-random 0
  foreach listProbability [
    x -> if x != item curs perfect-list-repartition [
      set error-distribution-random error-distribution-random + abs(item curs perfect-list-repartition - x)
    ] set curs curs + 1
  ]
end

;; Special Bernoulli
to bernoulli [num index]
  let i random-float 1
  ifelse i < berP [
    set listProbability replace-item index listProbability num
  ]
  [
    set listProbability replace-item index listProbability random (num + 1)
  ]
end

;; Distribute tasks
to distribute
  set ListP []
  set ratios-tasks read-from-string ratio-tasks
  set n-proba length ratios-tasks
  let curs 0
  foreach ratios-tasks [
    x ->
    if x > 1 [ set n-proba n-proba + 1 ]
      let i 0
      while [i < x][
        set ListP lput curs ListP
        set i i + 1
      ]
      set curs curs + 1
  ]
end

;; Second Distribution
to create-adaptive-probability [num]
  let len length ListTasksProbability
  let ran random len
  ask turtles with [id = num] [
    set task item ran ListTasksProbability
  ]
end

;; Update task list
to update-list-tasks
  set list-tasks [0 0 0 0 0 0 0 0 0 0 0 0 0]
  ask turtles with [task != -1][
    set list-tasks replace-item task list-tasks  ((item task list-tasks) + 1)
  ]
end

;; Error of second distribution
to random-distribution-2
  let curs 0
  set error-distribution-random2 0
  foreach list-tasks [
    x -> if x != item curs perfect-list-repartition [
      set error-distribution-random2 error-distribution-random2 + abs(item curs perfect-list-repartition - x)
    ] set curs curs + 1
  ]
end

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 2   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;;
to setup-patches
  ask patches [ set pcolor black ]
end

;; create a new "random" turtle
to create-new-turtle
  create-turtles 1 [
    set id number  ;; set id
    setxy random-xcor random-ycor  ;; set a random position (inutile ?)
    set task ( random nb-tasks )
    set color task-color task  ;;  set color
    add-task task
    init-lists task
  ]
end

;; link the new turtle to it's right manager and change it from worker to manager if needed
to link-new-turtle
  ;; not efficient at all... (better ?)
  if number > 0 [
    ask turtles with [ id = number ] [
      set manager floor ( (number - 1) / nb-management )
      create-link-to one-of turtles with [ id = manager ]  ;; one-of is necessary even in a set of one Vertex
      ask turtles with [ id = manager ] [
        set redo 0                   ;; reinitialize "redo" (may be used if call of add-worker)
        if ( task >= 0 ) [        ;; => the manager is a worker. Then the add of a vertex doesn't add a worker, just a manager. So the worker doesn't change task.
          let tmp task
          set redo 1                 ;; we will have to redo it one more time
          set color white          ;; change to being a manager
          set task -1              ;; manager
          set info []              ;; doesn't have any more info for the moment (until communication begins)
          set nb-managers ( nb-managers + 1 )
          ask turtles with [ id = number ] [
            remove-task task
            set task tmp                ;; in case we just add a manager (don't change task of the worker)
            set color task-color task
          ]
        ]
      ]
    ]
  ]
  set number (number + 1)
end

;; construct the layout of the tree
to make-tree
  layout-radial turtles links ( one-of turtles with [ id = 0 ] )
end

;; update depth of the tree
to update-depth                                 ;; in base nb-management
  if ( number > 1 ) [
    set depth ( floor ( log ((number - 1) * (nb-management - 1) + 1 ) nb-management ) )    ;; number - 1 ???
;    if ( nb-management = 2 ) [ set depth ( floor ( log number nb-management ) ) ]
;    if ( nb-management != 2 and number > 2 ) [ set depth ( floor ( log (number - 2) nb-management ) + 1 ) ]
  ]
  if (number = 1) [ set depth 0 ]
  if (number = 2) [ set depth 1 ]
end

;;
to display-labels
  ask turtles [
    set label-color black
    ifelse display-tasks
    [ set label task ]
    [
      ifelse display-id?
      [ set label id ]
      [ set label "" ]
    ]
  ]
end

;; increment count of workers on task t by one
to add-task [t]
  let current-val (item t list-tasks)
  set list-tasks (replace-item t list-tasks ( current-val + 1 ))
end

;; decrement count of workers on task t by one
to remove-task [t]
  set list-tasks replace-item t list-tasks ( item t list-tasks  - 1 )
end

;; set the right color in function of the task
to-report task-color [t]
  report ( t * 10 + 15 )
end

;;
to manager-to-worker? [n tmp]
  if ( (number - 1) / nb-management = floor (number / nb-management) ) [    ;; if worker deleted was the only one under its manager
    ask turtles with [ id = ( floor (number / nb-management)) ] [           ;; ask manager
      set nb-managers (nb-managers - 1)   ;; manager replaced by worker -> one less manager
      set task tmp                        ;; set it's task (keep the task of the deleted worker (not deleted in truth, the manager is deleted))
      add-task task                       ;; update the list-tasks list (in this case : cancel the remove-task made by default)
      init-lists task                     ;; update its info
      set color task-color task           ;; set its color according to its task
      ]
    ]
end

;;
to-report get-manager-of [n]       ;; curently unused
  report floor (n / nb-management)
end

;; initialize the ratios list
to initialize-ratios
  set ratios n-values nb-tasks [0]
  let ratios-tmp read-from-string ratio-tasks
  let i 0
  foreach ratios-tmp [
    x -> if (i < nb-tasks) [set ratios replace-item i ratios x]     ;; change ratios (x is the value of ratios-tmp currently treated) || if to avoid exeding list length
    set i (i + 1)                                                   ;; the rest of the list stays at 0
  ]
end

;; updates all turtles info
to update
  set info-from-childs info-from-childs-new
  set orders-received orders-received-new
  ;; Do we choose to keep the info and reupdate only when there is new info ???
  set info-from-childs-new []
  set orders-received-new []
  ;; But this is not efficient, it will reconstruct all the structure
end

;; context : a turtle
to communicate
  ;; ToDo : treat the new infos and give orders...
  if ( task = -1 ) [   ;; if manager
    info-down
    info-up
  ]
  if ( task >= 0 ) [   ;; if worker
    execute-order
    info-up   ;; ??? or a different one ?
  ]
end

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 3   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



;; initialise information and order lists of current turtles      ||      /!\ NEED TO INITIALIZE ALL OF THEM ????? (yes for some, with the tests "if ... != [])
to init-lists [t]
  set info-from-childs []          ;; unused for a worker
  set info n-values nb-tasks [0]   ;; init with [0 0 0 ...] (lenght = number of tasks)
  set info replace-item t info 1   ;; set a 1 for the task of the current worker
  set orders []                    ;; unused for a worker
  set orders-received []           ;; empty for now
  set info-from-childs-new []
  set orders-received-new []
end

to info-down
;  show info-from-childs
  if ( info-from-childs != [] ) [
;    show info-from-childs
    if ( orders-received = [] ) [ construct-orders ]
    analyse-orders
    give-orders
  ]
end

to info-up
  if (task = -1 and info-from-childs != []) [ construct-info ]
  if (task != -1) [ init-lists task ]
  send-info
end

to execute-order
  if (orders-received != []) [
    ifelse (position 1 orders-received != false) [     ;; PROBLEM !!!!!!!!!! the order-received is not conform
      remove-task task
      set task (position 1 orders-received)
      init-lists task
      add-task task
      set color (task-color task)
    ]
    [
      print "ERREUR"
      ;show orders-received                           ;; DEBUG
    ]
  ]
end


;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 4   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;; constructs orders-received from ratios
to construct-orders
  init-orders
  let list-worker-child construct-list-worker-child   ;; list-worker-child = list of the number of workers under each child ([1 2 4] -> 1 worker for child 0 ...)
  compute-orders list-worker-child
end

;; constructs orders from orders-received
to analyse-orders
  init-orders
  let list-worker-child construct-list-worker-child   ;; list-worker-child = list of the number of workers under each child ([1 2 4] -> 1 worker for child 0 ...)
  dispatch-orders list-worker-child
end

to give-orders
  let manager-id id
  let child-nb 0
  foreach orders [
    o -> ask turtles with [ id = (manager-id * nb-management + child-nb + 1) ] [ set orders-received-new o ]   ;; /!\ and if the child doesn't exists ??? What happens ?
    set child-nb (child-nb + 1)
  ]
end

;;
to construct-info
  set info (n-values nb-tasks [0])
  foreach info-from-childs [
    info-child -> let t 0
    foreach info-child [
      nb -> set info (replace-item t info ( (item t info) + nb ))
      set t (t + 1)
    ]
  ]
end

;;
to send-info
  if (id > 0 and info != []) [              ;; the racine (?) doesn't send info upstream !!!
    let info-send info
    let child-id id
    ask turtles with [id = floor ((child-id - 1) / nb-management)] [
      if (info-from-childs-new = []) [ set info-from-childs-new (n-values nb-management [[]]) ]    ;; Does it creates [[] [] [] ...] ???
      set info-from-childs-new ( replace-item ( (child-id - 1) mod nb-management ) info-from-childs-new info-send )
    ]
  ]
end


;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 5   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;; init the list orders with zeros (useful ???)
to init-orders
  set orders n-values nb-management [n-values nb-tasks [0]]
end

to-report construct-list-worker-child
  let list-worker-child ( n-values nb-management [0] )   ;; initialize list with [0 0 0 ...] nb-management times
  let i 0
  foreach info-from-childs
  [
    list-child -> let nb-w count-workers list-child    ;; nb-w = number of workers under child i
    set list-worker-child replace-item i list-worker-child nb-w
    set i (i + 1)
  ]
  report list-worker-child
end

to compute-orders [list-worker-child]
  init-orders-received
  let s sum-ratios
  let nb-workers-all count-all-workers
  make-orders-received-1 s nb-workers-all
end

;; take orders-received and list-worker-child and create orders (for its childs)
to dispatch-orders [list-worker-child]
;  show orders-received                                ;; DEBUG
;  show list-worker-child
;  show info-from-childs
  let task-ordered 0                                  ;; task-ordered = task currently treated (we assign workers on it)
  foreach orders-received                             ;; we go with each task to assign
  [
    x -> let n x                                      ;; n = number of worker we still need to assign to task task-ordered
    let child 0                                       ;; child = child to which we ask if he can assign workers to task-ordered
    while [ n > 0 and child < nb-management ] [                                 ;; while the number of workers on a task isn't enough, keep adding
      let nb-child (item child list-worker-child)     ;; nb-child = number of workers of the child currently available
      ifelse (nb-child >= n)
      [                                               ;; if the child have enough workers to fulfill the task :
        set list-worker-child replace-item child list-worker-child (nb-child - n)   ;; update the number of workers available of this child
        modify-orders child task-ordered n            ;; update the orders
        set n 0                                       ;; update the number of workers we still need to assign to task-ordered (in this case n <- 0)
      ]
      [                                               ;; if the child doesn't have enough workers to fulfill the task :
        set list-worker-child (replace-item child list-worker-child 0)
        modify-orders child task-ordered nb-child
        set n (n - nb-child)
      ]
      set child (child + 1)
    ]
    set task-ordered (task-ordered + 1)
  ]
end


;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 6   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;; count worker of a "manager" with its info
to-report count-workers [list-child]
  let nb 0             ;; nb = number of workers
  foreach list-child   ;; for each task, count number of workers and add it to the total number
  [
    x -> set nb (nb + x)
  ]
  report nb
end

;;
to init-orders-received
  set orders-received (n-values nb-tasks [0])
end

;;
to-report sum-ratios
  let s 0
  foreach ratios [ x -> set s (s + x) ]
  report s
end

;; from info-from-childs, count the total number of workers under a "manager"
to-report count-all-workers
  let nb 0
  foreach info-from-childs
  [
    info-of-child -> set nb (nb + (count-workers info-of-child))
  ]
  report nb
end

;; ~~~~~~~~~~~~~~~~~~~~   CHANGE REPARTITION PROCEDURE   ~~~~~~~~~~~~~~~~~~~~

;; construct pseudo "orders-received"  ||  with ceiling -> can create big inequalities with the last task
to make-orders-received-0 [s total-nb]
  let nb total-nb
  let current-task 0
  foreach ratios
  [
    r -> if (nb > 0) [
      let n (ceiling ( total-nb * (r / s) ))
      ifelse (n <= nb)
      [
        set orders-received (replace-item current-task orders-received n)
        set nb (nb - n)
      ]
      [
        set orders-received (replace-item current-task orders-received nb)
        set nb 0
      ]
    ]
    set current-task (current-task + 1)
  ]
end

;; BUG for the moment doesn't works
;; constructs pseudo "orders-received"  ||  with floor and redistribution -> better
to make-orders-received-1 [s total-nb]
  let nb total-nb
  let current-task 0
  foreach ratios
  [
    r -> if (nb > 0) [
      let n (floor ( total-nb * (r / s) ))
      ifelse (n <= nb)
      [
        set orders-received (replace-item current-task orders-received n)
        set nb (nb - n)
      ]
      [
        set orders-received (replace-item current-task orders-received nb)
        set nb 0
      ]
    ]
    set current-task (current-task + 1)
  ]
  let priority-list construct-priority-list
  print "prio"
  ;show priority-list
  foreach priority-list [
    t -> if (nb > 0) [ increase-workers-on t ]
    set nb (nb - 1)
  ]
end

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;;
to modify-orders [child task-ordered value]
  set orders replace-item child orders (replace-item task-ordered (item child orders) value)
end


;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   NIVEAU 7   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;;
to-report construct-priority-list
  let priority-list []
  let ratios-tmp ratios
  while [max ratios-tmp != 0] [     ;; if already 0 : not a problem because we don't have any worker to alocate
    let m (max ratios-tmp)
    let p (position m ratios-tmp)
    set priority-list (lput p priority-list)
    set ratios-tmp (replace-item p ratios-tmp 0)
  ]
  report priority-list
end

;;
to increase-workers-on [t]
  let current-val (item t orders-received)
  set orders-received (replace-item t orders-received (current-val + 1))
end


;; TEMPO




;; ToDo : changement de nombre de worker ajoutés ou supprimés en temps réel (direct quand on change la jauge) // OK
;; does only the manager 0 knows the ratios ??? Or everyone ?
;; ToDo : update-depth  ||  update  ||  analyse-orders
@#$#@#$#@
GRAPHICS-WINDOW
300
10
737
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
19
37
83
71
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
214
106
248
NIL
add-vertex
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
10
302
128
347
number of vertices
number
17
1
11

SLIDER
19
130
192
163
number-added
number-added
1
20
20.0
1
1
NIL
HORIZONTAL

SLIDER
19
171
192
204
number-deleted
number-deleted
1
20
3.0
1
1
NIL
HORIZONTAL

BUTTON
143
214
252
248
NIL
delete-vertex
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
11
352
69
397
NIL
depth
17
1
11

BUTTON
10
256
106
290
NIL
add-worker
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
143
256
253
290
NIL
delete-worker
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
142
303
254
348
number of worker
number-workers
17
1
11

SLIDER
19
88
192
121
nb-management
nb-management
2
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
754
19
926
52
nb-tasks
nb-tasks
1
13
6.0
1
1
NIL
HORIZONTAL

MONITOR
1065
286
1243
331
tasks-repartition
list-tasks
17
1
11

MONITOR
142
354
269
399
number of managers
nb-managers
17
1
11

PLOT
753
106
1035
309
Repartition of tasks
clock
number
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"managers" 1.0 0 -16777216 true "" "plot nb-managers"
"task 0" 1.0 0 -2674135 true "" "plot item 0 list-tasks"
"task 1" 1.0 0 -955883 true "" "plot item 1 list-tasks"
"task 2" 1.0 0 -6459832 true "" "plot item 2 list-tasks"
"task 3" 1.0 0 -1184463 true "" "plot item 3 list-tasks"
"task 4" 1.0 0 -10899396 true "" "plot item 4 list-tasks"
"task 5" 1.0 0 -13840069 true "" "plot item 5 list-tasks"
"task 6" 1.0 0 -14835848 true "" "plot item 6 list-tasks"
"task 7" 1.0 0 -11221820 true "" "plot item 7 list-tasks"
"task 8" 1.0 0 -13791810 true "" "plot item 8 list-tasks"
"task 9" 1.0 0 -13345367 true "" "plot item 9 list-tasks"
"task 10" 1.0 0 -8630108 true "" "plot item 10 list-tasks"
"task 11" 1.0 0 -5825686 true "" "plot item 11 list-tasks"
"task 12" 1.0 0 -2064490 true "" "plot item 12 list-tasks"

INPUTBOX
1048
108
1287
168
ratio-tasks
[1 1 1 1 1 1]
1
0
String

TEXTBOX
1053
43
1280
113
Enter a list of the weigh of each task\nExemple : 2 tasks and same weight -> [1 1] or [50 50]\n(no more than 13 elements)
11
0.0
1

BUTTON
1165
236
1244
269
NIL
organise
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
1050
182
1236
215
charge the new ratio values
charge-ratios
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
754
64
881
97
display-tasks
display-tasks
0
1
-1000

SWITCH
893
64
1006
97
display-id?
display-id?
1
1
-1000

MONITOR
1064
340
1243
385
perfect list repartition
perfect-list-repartition
19
1
11

PLOT
753
319
1039
439
Error Distribution
clock
Turtles
0.0
10.0
0.0
50.0
true
false
"" ""
PENS
"Standard" 1.0 0 -5298144 true "" "plot error-distribution "
"Bernoulli" 1.0 0 -14439633 true "" "plot error-distribution-random"
"pen-2" 1.0 0 -11221820 true "" "plot error-distribution-random2"

MONITOR
1063
393
1243
438
Bernoulli-Distribution
listProbability
17
1
11

SWITCH
1035
236
1162
269
Run-Random
Run-Random
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
