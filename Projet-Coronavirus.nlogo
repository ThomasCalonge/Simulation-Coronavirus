;;;;;;;;;;;;;;;;;;;;;
;; Input Variables ;;
;;;;;;;;;;;;;;;;;;;;;


;; inputs [
;;
;;   ticks-a-day                            ;; int - how many ticks happen per day
;;   p-mob-to-die-init                      ;; int - how many ticks happen per day
;;   p-mob-to-go-init                       ;; int - how many ticks happen per day
;;   p-sed-to-die-init                      ;; int - how many ticks happen per day
;;   p-sed-to-go-init                       ;; int - how many ticks happen per day
;;
;; ]





;;;;;;;;;;;;;;;;;;
;; Declarations ;;
;;;;;;;;;;;;;;;;;;

globals [
  ;; when multiple runs are recorded in the plot, this
  ;; tracks what run number we're on
  run-number

  nb-sick                                   ;; int - count turtles with [ is-sick? ]
  nb-incubating                             ;; int - count turtles with [ is-incubating? ]
  nb-immune                                 ;; int - count turtles with [ is-immune? ]
  nb-in-intensive-care                      ;; int - count turtles with [ is-immune? ]

  nb-confined                               ;; int - count turtles with [ is-confined? ]
  nb-rebels                                 ;; int - count turtles with [ is-rebel? ]
  nb-has-mask                               ;; int - count turtles with [ has-mask? ]
  nb-needs-care                             ;; int - count turtles with [ needs-care? ]

  nb-sedentaries                            ;; int - count sedentaries
  nb-mobiles                                ;; int - count sedentaries


  nb-infected                               ;; int - total of infected people during simulation
  nb-deaths                                 ;; int - total of deaths during simulaiton
  nb-alives                                 ;; int - remaing alive people

  nb-ic-places                              ;; int - intensive care places
  init-ic-places-growth                     ;; int - initial i.c. places growth rate
  nb-free-ic-places                         ;; int - available intensive care places
  ic-places-growth                          ;; int - intensive care places growth rate

  in-confinement?                           ;; bool - whether confinement is or not
  days                                      ;; int - days
  days-til-confinement                      ;; int - days until confinement
  days-of-confinement                       ;; int - days of confinement
  days-sin-confinement                      ;; int - days since confinement
  days-sin-critical                         ;; int - days since confinement
  already-happened?                         ;; bool - whether confinement has been or not yet
  growth-start?                             ;; bool - certain values are evolving when confinement has started
  once-per-day                              ;; bool - unconfine people only once per day
  patches-with-germs                        ;; int - number of patches with germ
  amount-of-germs                           ;; int - amount of germs on the map
]

breed [ sedentaries sedentary ]
breed [ mobiles mobile ]

;; patches variables
patches-own [
  dying-time                                ;; int - turtles own timer for incubating, sick or dying.
  has-germs?                                ;; bool - whether there are germs on a patch
  germs-amount                              ;; int - 0-100 amount of germs on a patch
]

;; turtles variables
turtles-own [
  has-mask?                                 ;; bool - whether turtle has a mask
  is-rebel?                                 ;; bool - whether turtle is a rebel
  is-sick?                                  ;; bool - whether turtle is sick
  needs-care?                               ;; bool - whether turtle needs to be in intensive care
  in-intensive-care?                        ;; bool - whether turtle is in intensive care
  is-incubating?                            ;; bool - whether turtle is incubating
  is-immune?                                ;; bool - whether turtle is immune
  is-confined?                              ;; bool - whether turtle is confined
  count-time                                ;; int - timer for incubating, being sick or dying
  proba-to-die                              ;; int - death probability - probabilities are increasing if turtle is not in intensive care
  proba-to-go                               ;; int - each 3 days, probability to go for the turtle are increasing
]

;; sedentary turtles variables
sedentaries-own [
  is-work-done?                             ;; bool - whether turtle has been to work today
  house                                     ;; patch - turtle spawn patch
  work                                      ;; patch - turtle work patch at a random radius between 3-20 patches away
]

;; mobile turtle variables
mobiles-own [
  road-done                                 ;; int - change orientation every 5 ticks
]

;;;;;;;;;;;;;;;;;;;;;
;; Setup Functions ;;
;;;;;;;;;;;;;;;;;;;;;

;; clears the plot too
to setup-clear
  clear-all
  set run-number 1
  setup-world
end

;; note that the plot is not cleared so that data
;; can be collected across runs
to setup-keep
  clear-turtles
  clear-patches
  set run-number                            (run-number + 1)
  setup-world
end

to setup-world
  ;; All values to 0.
  set-default-shape turtles "android"

  set nb-sick                               0
  set nb-infected                           0
  set nb-incubating                         0
  set nb-immune                             0
  set nb-in-intensive-care                  0
  set nb-has-mask                           0
  set nb-confined                           0
  set nb-rebels                             0
  set nb-needs-care                         0
  set nb-sedentaries                        0
  set nb-mobiles                            0
  set nb-deaths                             0
  set patches-with-germs                    0
  set amount-of-germs                       0
  set days                                  0
  set days-til-confinement                  0
  set days-of-confinement                   0
  set days-sin-confinement                  0
  set days-sin-critical                     0
  set growth-start?                         false
  set already-happened?                     false
  set in-confinement?                       false
  set once-per-day                          false
  set nb-alives                             nb-people
  set nb-ic-places                          int (nb-people * (intensive-care-places / 1000))
  set init-ic-places-growth                 int (nb-ic-places * (ic-places-growth-rate / 100))
  set nb-free-ic-places                     nb-ic-places
  let width                                 int (nb-people * 0.0256)
  let mid                                   int (width / 2)
  let m-mid                                 mid * -1
  let pa-size                               (512 / width)
  resize-world                              m-mid mid m-mid mid
  set-patch-size                            pa-size
  ask patches [ set has-germs?              false ]
  create-people
  reset-ticks
end



to create-people
  create-sedentaries int (nb-people * ((100 - mobiles-part) / 100)) [

    set nb-sedentaries                      (nb-sedentaries + 1)
    let x random-pxcor
    let y random-pycor

    ;; put androids on patch centers
    setxy x y

    set house                               patch-here
    set work                                one-of patches in-radius ((random 17) + 3)

    set color                               gray

    ;; start value
    set count-time                          1

    set is-sick?                            false
    set is-incubating?                      false
    set needs-care?                         false
    set is-immune?                          false
    set in-intensive-care?                  false
    set is-work-done?                       false

    ;; confinement related boolean value.
    set has-mask?                           false
    set is-confined?                        false

    set proba-to-die                        p-sed-to-die-init
    set proba-to-go                         p-sed-to-go-init

    ifelse(random 100 < desobediance-rate)
    [
      set is-rebel?                         true
      set nb-rebels                         (nb-rebels + 1)
    ]
    [ set is-rebel?                         false ]
  ]
  create-mobiles int (nb-people * (mobiles-part / 100)) [
    set nb-mobiles                          (nb-mobiles + 1)

    let x random-pxcor
    let y random-pycor

    ;; put androids on patch centers
    setxy x y

    set color                               gray
    set heading                             90 * random 4

    ;; start value
    set count-time                          1

    ;; all boolean value to false, means the agent is sane
    set is-sick?                            false
    set is-incubating?                      false
    set needs-care?                         false
    set in-intensive-care?                  false
    set is-immune?                          false

    set is-confined?                        false
    set has-mask?                           false

    set proba-to-die                        p-mob-to-die-init
    set proba-to-go                         p-mob-to-go-init

    ifelse (random 100 < desobediance-rate)
    [
      set is-rebel?                         true
      set nb-rebels                         (nb-rebels + 1)
    ]
    [ set is-rebel?                         false ]
  ]
end


;; infect a person
to infect
  ask one-of turtles [ get-sick ]
end


to give-mask
  let nb-step                               int (nb-alives * (having-mask-rate / 100))
  ask turtles [
    if (not has-mask? and nb-step > 0) [
      set has-mask?                         true
      set nb-has-mask                       (nb-has-mask + 1)
      set nb-step                           (nb-step - 1)
    ]
  ]
end

to mask-growth
  if (in-confinement? or (nb-needs-care > nb-free-ic-places)) [
    let nb-no-mask                          (nb-alives - nb-has-mask)
    if (nb-no-mask > 0) [
      let nb-step                           (nb-no-mask * (having-mask-growth / 100))
      ask turtles [
        if (not has-mask? and nb-step > 0 and once-per-day) [
          set has-mask?                     true
          set nb-has-mask                   (nb-has-mask + 1)
          set nb-step                       (nb-step - 1)
        ]
      ]
    ]
  ]
end


to rebels-degrowth
  ;; Rebels number degrowth
  if (nb-rebels > 0) [
    let nb-step                             int (nb-rebels * (desobedience-degrowth / 100))
    ask turtles [
      if (is-rebel? and nb-step > 0 and once-per-day) [
        set is-rebel?                       false
        set nb-rebels                       (nb-rebels - 1)
        set nb-step                         (nb-step - 1)
      ]
    ]
  ]
end


to ic-places-variation
  if (once-per-day) [
    let nb-occ-ic-places                      (nb-ic-places - nb-free-ic-places)
    set nb-ic-places                          (nb-ic-places + init-ic-places-growth)
    set nb-free-ic-places                     (nb-ic-places - nb-occ-ic-places)
  ]
end


;; methods to choose the turtles who will be confined
to confine-people
  set in-confinement?                       true
  set days-sin-confinement                  0
  ;; reset number of confined in model stop and go.
  if (already-happened? and stop-and-go?) [
    ask turtles [
      ifelse (is-confined?)
      [
        set is-confined?                    false
        set nb-confined                     (nb-confined - 1)
      ]
      [ stop ]
    ]
  ]
  let nb-step                               int (nb-sedentaries * 0.9)
  ask sedentaries [
    if (not is-confined? and (nb-step > 0)) [
      set is-confined?                      true
      set nb-confined                       (nb-confined + 1)
      set nb-step                           (nb-step - 1)
    ]
  ]
end

;; unconfine people
;; give a mask to some people
to unconfine-people
set in-confinement?                         false
  if (not already-happened?) [
    set already-happened?                   true
    give-mask
  ]
  unconfine-people-progressive
end

to unconfine-people-progressive
  if (((days-sin-confinement = 0) or ((days-sin-confinement mod 7) = 0)) and once-per-day) [
    let nb-step                             int (nb-sedentaries * (progressive-unconfining-rate / 100)) ;; Thomas
    ask turtles [
      if (is-confined? and not is-sick? and (nb-step > 0)) [
        set is-confined?                    false
        set nb-confined                     (nb-confined - 1)
        set nb-step                         (nb-step - 1)
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Functions ;;
;;;;;;;;;;;;;;;;;;;;;;;

to go
  if (nb-sick = 0 and nb-incubating = 0 and patches-with-germs = 0 and amount-of-germs = 0) [
    stop
  ]

  let critical-amount?                      (nb-sick * (%detected / 100) > nb-alives * (infected-people-trigger / 100))

  ;; each week, there an increase values of things
  ;; we are not in a static model.
  if ((critical-amount? and not growth-start?) or (growth-start? and (days-sin-critical mod 7) = 0)) [
    mask-growth
    ic-places-variation
    rebels-degrowth
    if (not growth-start?) [
      set growth-start?                     true
    ]
  ]

  if (confinement) [
    if (already-happened? and not in-confinement?) [
      unconfine-people-progressive
    ]
    if ((days-of-confinement > confinement-duration) and in-confinement? and (not already-happened? or stop-and-go?)) [
      unconfine-people
    ]
    if (critical-amount? and not in-confinement? and (not already-happened? or (stop-and-go? and days-sin-confinement > j-stop-and-go))) [
      confine-people
    ]
  ]

  set once-per-day                          false

  if ((ticks mod ticks-a-day) = 0) [
    set days                                (days + 1)
    set once-per-day                        true
    if (growth-start?) [
      set days-sin-critical                 (days-sin-critical + 1)
    ]
    if (confinement) [
      ifelse (not already-happened? and not in-confinement?)
      [
        set days-til-confinement            (days-til-confinement + 1)
      ]
      [
        ifelse (in-confinement?)
        [
          set days-of-confinement           (days-of-confinement + 1)
        ]
        [
          if (already-happened?) [
            set days-sin-confinement        (days-sin-confinement + 1)
          ]
        ]
      ]
    ]
  ]

  ;; now for the main stuff;
  sickness-evolution
  androids-wander

  ;; infected people spit their lungs on surfaces
  ask turtles with [ (is-incubating?) or (is-sick? and not in-intensive-care?) ] [
    spread-disease-turtle
  ]

  ;; germs spread virus
  ask patches with [ has-germs? ] [
    spread-disease-patch
  ]

  tick
end

to sickness-evolution

  ;; each tick kill virus
  ask patches [
    ifelse (germs-amount > 0)
    [
      set dying-time                        (dying-time + 1)
      if (dying-time = ticks-a-day) [
        set dying-time                      0
        let local-germs-amount              germs-amount
        ifelse (local-germs-amount > 20)
        [
          set has-germs?                    true
          set germs-amount                  (germs-amount - 20)
          set amount-of-germs               (amount-of-germs - 20)
        ]
        [
          set has-germs?                    false
          set patches-with-germs            (patches-with-germs - 1)
          set germs-amount                  0
          set amount-of-germs               (amount-of-germs - local-germs-amount)
          set pcolor                        black
        ]
      ]
      if (has-germs?) [
        ifelse (germs-amount >= 80)
        [
          set pcolor                          75
        ]
        [
          ifelse (germs-amount >= 40)
          [
            set pcolor                          74
          ]
          [
            ifelse (germs-amount >= 20)
            [
              set pcolor                          73
            ]
            [
              set pcolor                          50
            ]
          ]
        ]
      ]
    ]
    [
      set has-germs?                        false
      set pcolor                            50
    ]
  ]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; PROCEDURE WHEN IN INCUBATION  ;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;; incubation after an elpased time

  ask turtles [
    ifelse (is-incubating?)
    [
      ifelse (count-time mod ((random (14 - 3) + 3) * ticks-a-day) = 0)
      [
        set is-incubating?                  false
        set nb-incubating                   (nb-incubating - 1)
        set is-sick?                        true
        set nb-sick                         (nb-sick + 1)
        set color                           green
        set count-time                      1
      ]
      [ set count-time                      (count-time + 1) ]
    ]
    [
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; PROCEDURE WHEN IN SICKNESS  ;;
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      ifelse (is-sick? and not needs-care? and not in-intensive-care?)
      [
        if (count-time mod (7 * ticks-a-day) = 0) [
          set is-immune?                    true
          set nb-immune                     (nb-immune + 1)
          set is-sick?                      false
          set nb-sick                       (nb-sick - 1)
          set color                         blue
          stop
        ]
        ;; Every 12 ticks, turtle rolls dice to go
        ;; in intensive care or not with a 1% risk
        ifelse ((count-time mod ticks-a-day = 0) and (random 100 < 1))
        [
          set needs-care?                   true
          set nb-needs-care                 (nb-needs-care + 1)
          set color                         red
          set count-time                    1
        ]
        [ set count-time                    (count-time + 1) ]
      ]
      [
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; PROCEDURE WHEN IN INTENSIVE CARE  ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        if (needs-care?) [
          let is-three-days?                (count-time mod (ticks-a-day * 3)) = 0
          if (is-three-days?) [
            ifelse (random 100 < proba-to-go)
            [
              if (in-intensive-care?) [
                set nb-free-ic-places       (nb-free-ic-places + 1)
                set in-intensive-care?      false
                set nb-in-intensive-care    (nb-in-intensive-care - 1)
              ]
              set needs-care?               false
              set nb-needs-care             (nb-needs-care - 1)
              set is-sick?                  false
              set nb-sick                   (nb-sick - 1)
              set is-immune?                true
              set nb-immune                 (nb-immune + 1)
              set color                     blue
              stop
            ]
            [
              ifelse (in-intensive-care?)
              [ set proba-to-go             (proba-to-go + 15) ]
              [ set proba-to-go             (proba-to-go + 5) ]
            ]
          ]
          ;; taking one intensive care slot
          if (nb-free-ic-places > 0 and not in-intensive-care?) [
            set proba-to-die                5
            set proba-to-go                 20
            set nb-free-ic-places           (nb-free-ic-places - 1)
            set in-intensive-care?          true
            set nb-in-intensive-care        (nb-in-intensive-care + 1)
          ]
          if (is-three-days?) [
            ifelse (in-intensive-care?)
            [
              ifelse (random 100 < proba-to-die)
              [
                set nb-deaths               (nb-deaths + 1)
                set nb-alives               (nb-alives - 1)
                set nb-free-ic-places       (nb-free-ic-places + 1)
                set nb-in-intensive-care    (nb-in-intensive-care - 1)
                if (breed = sedentaries)    [ set nb-sedentaries (nb-sedentaries - 1) ]
                if (breed = mobiles)        [ set nb-mobiles (nb-mobiles - 1) ]
                if (is-confined?)           [ set nb-confined (nb-confined - 1) ]
                if (is-rebel?)              [ set nb-rebels (nb-rebels - 1) ]
                if (is-sick?)               [ set nb-sick (nb-sick - 1) ]
                if (has-mask?)              [ set nb-has-mask (nb-has-mask - 1) ]
                if (needs-care?)            [ set nb-needs-care (nb-needs-care - 1) ]
                die
              ]
              [ set proba-to-die            (proba-to-die + 5) ]
            ]
            [
              ifelse (random 100 < proba-to-die)
              [
                set nb-deaths               (nb-deaths + 1)
                set nb-alives               (nb-alives - 1)
                if (breed = sedentaries)    [ set nb-sedentaries          (nb-sedentaries - 1) ]
                if (breed = mobiles)        [ set nb-mobiles              (nb-mobiles - 1) ]
                if (is-confined?)           [ set nb-confined             (nb-confined - 1) ]
                if (is-rebel?)              [ set nb-rebels               (nb-rebels - 1) ]
                if (is-sick?)               [ set nb-sick                 (nb-sick - 1) ]
                if (has-mask?)              [ set nb-has-mask             (nb-has-mask - 1) ]
                if (needs-care?)            [ set nb-needs-care           (nb-needs-care - 1) ]
                die
              ]
              [ set proba-to-die            (proba-to-die + 15) ]
            ]
          ]
          set count-time                    (count-time + 1)
        ]
      ]
    ]
  ]
end

;; controls the motion of the androids
to androids-wander
  ask turtles [
    ifelse (breed = sedentaries and not needs-care?)
    [

      ;; 1% probability to go abroad
      if ((random 100 > 98) and not is-confined? and (ticks mod 20 = 0)) [
        setxy random-pxcor random-pycor
      ]

      ;; Commuting back to home
      if (patch-here = work) [
        set is-work-done?                   true
      ]

      ;; Commuting to work
      if (patch-here = house) [
        set is-work-done?                   false
      ]

      ;; face direction
      ifelse (is-work-done? and not is-confined?)
      [ face house fd 1 ]
      [ face work fd 1 ]

      ;; returns home
      if (patch-here != house and is-confined?) [
        move-to house
      ]

      ;; if a citizen does not stay at home,
      ;; then he takes his dog out
      if (is-confined? and (ticks mod 5 = 0) and (patch-here = house) and is-rebel?) [
        rt 45 * random 8
        fd 1
      ]
    ]
    [
      if (breed = mobiles and not needs-care?) [
        if (road-done mod 5 = 0) [
          rt (random 180) - 90
        ]
        set road-done                       road-done + 1
        fd 3
      ]
    ]
  ]
end

;; turtle procedure
;; if the turtle has a mask, %chance of impact-of-mask.
to spread-disease-turtle
  if (has-mask? and (random 100 < mask-protection-rate)) [
    stop
  ]

  ;; Neighbors talking face-to-face
  if (not in-confinement? or is-rebel?) [
    ;; 20% for an encounter between two turtles.
    if (random 100 < 20) [
      if (count other turtles-here != 0) [
        ask one-of other turtles-here [ maybe-get-sick ]
      ]
    ]
  ]

  ask patch-here [
    if (random 100 > 50) [
      ifelse (has-germs?)
      [
        set germs-amount                      (germs-amount + 10)
        set amount-of-germs                   (amount-of-germs + 10)
        set dying-time                        (dying-time - 1)
      ]
      [
        set has-germs?                        true
        set patches-with-germs                (patches-with-germs + 1)
        set germs-amount                      20
        set amount-of-germs                   (amount-of-germs + 20)
        set dying-time                        0
      ]
    ]
  ]

end

;; patch procedure
;; > if a turtle is on a patch, then
;; > it'll be infected depending on germ rate
to spread-disease-patch
  if (random 100 > germs-amount / 2) [
    ask turtles-here [ maybe-get-sick ]
  ]
end

;; turtle procedure
;; > rolls the dice and maybe become sick
to maybe-get-sick
  if (not is-sick? and not is-immune? and not needs-care? and not is-incubating? and not is-confined? and random 100 < contagiousness) [
    get-sick
  ]
end

;; turtle procedure
;; > set the appropriate variables to make this turtle sick
to get-sick
  set is-incubating?                        true
  set nb-incubating                         nb-incubating + 1
  set color                                 white
  set nb-infected                           nb-infected + 1
end

;; Projet de recherche M1 Informatique CILS, Guillaume COQUARD et Thomas CALONGE -- Année 2020
@#$#@#$#@
GRAPHICS-WINDOW
690
678
1461
1450
-1
-1
2.0
1
10
1
1
1
0
0
0
1
-128
128
-128
128
1
1
1
ticks
1.0

BUTTON
9
403
123
436
Clear & Setup
setup-clear
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
9
479
123
512
Start
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
9
45
241
78
contagiousness
contagiousness
0
100
90.0
1
1
%
HORIZONTAL

PLOT
252
10
640
337
Model Evolution
Time
People in %
0.0
10.0
0.0
5.0
true
true
"" ""
PENS
"Sick" 1.0 0 -2674135 true "create-temporary-plot-pen word \"run \" run-number\nset-plot-pen-color item (run-number mod 5)\n                        [blue red green orange violet]" "plot (nb-sick / nb-people) * 100"
"Incubating" 1.0 0 -8732573 true "" "plot (nb-incubating / nb-people) * 100"
"Immunized" 1.0 0 -13791810 true "" "plot (nb-immune / nb-people) * 100"
"Deaths" 1.0 0 -16777216 true "" "plot (nb-deaths / nb-people) * 100"
"Infected" 1.0 0 -4079321 true "" "plot (nb-infected / nb-people) * 100"

SLIDER
9
10
241
43
nb-people
nb-people
0
100000
10000.0
1000
1
NIL
HORIZONTAL

MONITOR
642
151
834
196
Sick
nb-sick
0
1
11

BUTTON
9
438
123
471
Keep & Setup
setup-keep
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
135
448
232
466
keeps old plots
11
0.0
0

TEXTBOX
135
413
232
431
clears old plots\n
11
0.0
0

BUTTON
131
480
246
513
Infect
infect
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
1294
269
1547
302
intensive-care-places
intensive-care-places
0
1000
1.0
1
1
NIL
HORIZONTAL

PLOT
844
11
1292
337
Intensive Care Informations
Time
People
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"In Need of Care" 1.0 0 -2674135 true "" "plot nb-needs-care"
"Intensive Care Slot" 1.0 0 -16777216 true "" "plot nb-ic-places"
"Available Slot" 1.0 0 -14439633 true "" "plot nb-free-ic-places"

MONITOR
642
104
834
149
Incubating
nb-incubating
17
1
11

SWITCH
9
80
241
113
confinement
confinement
0
1
-1000

SLIDER
9
185
241
218
infected-people-trigger
infected-people-trigger
0
5
0.01
0.001
1
NIL
HORIZONTAL

SLIDER
9
115
241
148
confinement-duration
confinement-duration
1
120
50.0
1
1
NIL
HORIZONTAL

SLIDER
448
765
680
798
desobediance-rate
desobediance-rate
0
100
0.0
1
1
NIL
HORIZONTAL

MONITOR
9
520
247
565
Are People Confined ?
in-confinement?
17
1
11

SLIDER
252
718
441
751
having-mask-rate
having-mask-rate
0
100
0.0
1
1
NIL
HORIZONTAL

MONITOR
252
671
441
716
People Having a Mask
nb-has-mask
17
1
11

SLIDER
9
220
241
253
progressive-unconfining-rate
progressive-unconfining-rate
1
100
10.0
1
1
NIL
HORIZONTAL

MONITOR
9
661
247
706
Days since Confinement
days-sin-confinement
0
1
11

SLIDER
252
788
441
821
mask-protection-rate
mask-protection-rate
0
100
98.0
1
1
NIL
HORIZONTAL

MONITOR
1294
11
1497
56
People in Need of Care
nb-needs-care
0
1
11

SLIDER
9
150
241
183
%detected
%detected
0
100
60.0
1
1
NIL
HORIZONTAL

SWITCH
10
269
242
302
stop-and-go?
stop-and-go?
0
1
-1000

MONITOR
642
347
834
392
Triggering Infected People Amount
nb-people * (infected-people-trigger / 100)
0
1
11

SLIDER
10
304
242
337
j-stop-and-go
j-stop-and-go
0
60
14.0
1
1
NIL
HORIZONTAL

SLIDER
252
753
441
786
having-mask-growth
having-mask-growth
0
100
0.0
1
1
NIL
HORIZONTAL

SLIDER
448
800
680
833
desobedience-degrowth
desobedience-degrowth
0
100
3.0
1
1
NIL
HORIZONTAL

SLIDER
1294
304
1547
337
ic-places-growth-rate
ic-places-growth-rate
0
100
15.0
1
1
NIL
HORIZONTAL

MONITOR
642
577
834
622
Bad Citizen
nb-rebels
17
1
11

MONITOR
642
198
834
243
Immunized
nb-immune
17
1
11

MONITOR
642
245
834
290
Dead
nb-deaths
17
1
11

TEXTBOX
482
590
632
608
NIL
11
0.0
0

MONITOR
642
292
834
337
Lethality
(nb-deaths / nb-infected) * 100
2
1
11

MONITOR
642
10
834
55
Alives
nb-alives
17
1
11

MONITOR
642
57
834
102
Infected
nb-infected
17
1
11

PLOT
252
347
640
669
Confinement Informations
Time
People in %
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Confined" 1.0 0 -16777216 true "" "plot nb-confined / nb-alives * 100"
"Bad Citizen" 1.0 0 -2674135 true "" "plot nb-rebels / nb-alives * 100"
"Good Citizen" 1.0 0 -14439633 true "" "plot (nb-alives - nb-rebels) / nb-alives * 100"
"Having Mask" 1.0 0 -955883 true "" "plot nb-has-mask / nb-people * 100"

MONITOR
642
483
834
528
Confined
nb-confined
17
1
11

MONITOR
642
530
834
575
Not Confined
nb-alives - nb-confined
17
1
11

MONITOR
642
624
834
669
Good Citizen
nb-alives - nb-rebels
17
1
11

MONITOR
448
671
640
716
Sedentaries
nb-sedentaries
17
1
11

MONITOR
448
718
640
763
Mobiles
nb-mobiles
17
1
11

MONITOR
1294
58
1497
103
Intensive Care Slot
nb-ic-places
0
1
11

MONITOR
1294
105
1497
150
Available Slots
nb-free-ic-places
0
1
11

MONITOR
9
567
247
612
Days until Confinement
days-til-confinement
0
1
11

MONITOR
9
614
247
659
Days of Confinement
days-of-confinement
2
1
11

SLIDER
9
777
181
810
ticks-a-day
ticks-a-day
1
24
12.0
1
1
NIL
HORIZONTAL

MONITOR
9
344
243
397
Days
days
0
1
13

SLIDER
9
813
181
846
mobiles-part
mobiles-part
0
100
3.0
1
1
NIL
HORIZONTAL

SLIDER
9
885
181
918
p-mob-to-go-init
p-mob-to-go-init
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
9
849
181
882
p-mob-to-die-init
p-mob-to-die-init
0
100
35.0
1
1
NIL
HORIZONTAL

SLIDER
184
885
356
918
p-sed-to-go-init
p-sed-to-go-init
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
184
849
356
882
p-sed-to-die-init
p-sed-to-die-init
0
100
35.0
1
1
NIL
HORIZONTAL

MONITOR
9
708
247
753
Days since first Critical Peak
days-sin-critical
0
1
11

MONITOR
1294
347
1407
392
Infected Patches
patches-with-germs
0
1
11

MONITOR
1294
394
1465
439
Amount of Germs on Map
amount-of-germs
0
1
11

PLOT
844
347
1292
669
Surface Infection Rate
Time
Patches
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Infected Patches" 1.0 0 -11085214 true "" "plot (patches-with-germs / (world-width * world-height)) * 100"

@#$#@#$#@
## WHAT IS IT?

Disease Solo is a one-player version of the HubNet activity Disease.  It simulates the spread of a disease through a population.  One agent in the population is a person controlled by the user; the others are "androids" controlled by the computer.

## HOW IT WORKS

The user controls the blue agent via the buttons and slider on the right side of the view.  The infection is started by pressing the "infect" button.

Sick agents are indicated by a red circle.

Androids can move using a few different simple strategies. By default they simply move randomly, however, using the AVOID? and CHASE? switches you can indicate that uninfected androids should run from infected ones or infected androids should chase uninfected ones.

The person may also catch the infection.

Healthy "agents" on the same patch as sick agents have an contagiousness chance of becoming ill.

## HOW TO USE IT

### Buttons

SETUP/CLEAR - sets up the world and clears plots.
SETUP/KEEP - sets up the world without clearing the plot; this lets you compare results from different runs.
GO - runs the simulation.
INFECT - infects one of the androids

### Sliders

NUM-ANDROIDS - determines how many androids are created at setup
contagiousness - a healthy agent's chance at every time step to become sick if it is on the same patch as an infected agent

### Monitors

NUMBER SICK - the number of sick agents

### Plots

NUMBER SICK - the number of sick agents versus time

### Switches

AVOID? - when this switch is on each uninfected android checks all four directions to see if it can move to a patch that is safe from infected agents.
CHASE? - when this switch is on each infected androids checks all four directions to see if it can infect another agent.

### User controls

UP, DOWN, LEFT, and RIGHT - move the person around the world, STEP-SIZE determines how far the person moves each time one of the control buttons is pressed.

## THINGS TO NOTICE

Think about how the plot will change if you alter a parameter.  Altering the infection chance will have different effects on the plot.

## THINGS TO TRY

Do several runs of the model and record a data set for each one by using the setup/keep button. Compare the different resulting plots.

What happens to the plot as you do runs with more and more androids?

## EXTENDING THE MODEL

Currently, the agents remain sick once they're infected.  How would the shape of the plot change if agents eventually healed?  If, after healing, they were immune to the disease, or could still spread the disease, how would the dynamics be altered?

The user has a distinct advantage in this version of the model (assuming that the goal is either not to become infected, or to infect others), as the user can see the entire world and the androids can only see one patch ahead of them.  Try to even out the playing field by giving the androids a larger field of vision.

Determining the first agent who is infected may impact the way disease spreads through the population.  Try changing the target of the first infection so it can be determined by the user.

## NETLOGO FEATURES

You can use the keyboard to control the person.  To activate the keyboard shortcuts for the movement button, either hide the command center or click in the white background.

The plot uses temporary plot pens, rather than a fixed set of permanent plot pens, so you can use the setup/keep button to overlay as many runs as you want.

## RELATED MODELS

* Disease (HubNet version)
* Virus
* HIV

## CREDITS AND REFERENCES

This model is a one player version of the HubNet activity Disease.  In the HubNet version, multiple users can participate at once.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (2005).  NetLogo Disease Solo model.  http://ccl.northwestern.edu/netlogo/models/DiseaseSolo.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2005 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2005 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

airplane sick
false
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15
Circle -2674135 true false 156 156 108

android
false
0
Polygon -7500403 true true 210 90 240 195 210 210 165 90
Circle -7500403 true true 110 3 80
Polygon -7500403 true true 105 88 120 193 105 240 105 298 135 300 150 210 165 300 195 298 195 240 180 193 195 88
Rectangle -7500403 true true 127 81 172 96
Rectangle -16777216 true false 135 33 165 60
Polygon -7500403 true true 90 90 60 195 90 210 135 90

android sick
false
0
Polygon -7500403 true true 210 90 240 195 210 210 165 90
Circle -7500403 true true 110 3 80
Polygon -7500403 true true 105 88 120 193 105 240 105 298 135 300 150 210 165 300 195 298 195 240 180 193 195 88
Rectangle -7500403 true true 127 81 172 96
Rectangle -16777216 true false 135 33 165 60
Polygon -7500403 true true 90 90 60 195 90 210 135 90
Circle -2674135 true false 150 120 120

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

box sick
false
0
Polygon -7500403 true true 150 285 270 225 270 90 150 150
Polygon -7500403 true true 150 150 30 90 150 30 270 90
Polygon -7500403 true true 30 90 30 225 150 285 150 150
Line -16777216 false 150 285 150 150
Line -16777216 false 150 150 30 90
Line -16777216 false 150 150 270 90
Circle -2674135 true false 170 178 108

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

butterfly sick
false
0
Rectangle -7500403 true true 92 135 207 224
Circle -7500403 true true 158 53 134
Circle -7500403 true true 165 180 90
Circle -7500403 true true 45 180 90
Circle -7500403 true true 8 53 134
Line -16777216 false 43 189 253 189
Rectangle -7500403 true true 135 60 165 285
Circle -7500403 true true 165 15 30
Circle -7500403 true true 105 15 30
Line -7500403 true 120 30 135 60
Line -7500403 true 165 60 180 30
Line -16777216 false 135 60 135 285
Line -16777216 false 165 285 165 60
Circle -2674135 true false 156 171 108

cactus
false
0
Rectangle -7500403 true true 135 30 175 177
Rectangle -7500403 true true 67 105 100 214
Rectangle -7500403 true true 217 89 251 167
Rectangle -7500403 true true 157 151 220 185
Rectangle -7500403 true true 94 189 148 233
Rectangle -7500403 true true 135 162 184 297
Circle -7500403 true true 219 76 28
Circle -7500403 true true 138 7 34
Circle -7500403 true true 67 93 30
Circle -7500403 true true 201 145 40
Circle -7500403 true true 69 193 40

cactus sick
false
0
Rectangle -7500403 true true 135 30 175 177
Rectangle -7500403 true true 67 105 100 214
Rectangle -7500403 true true 217 89 251 167
Rectangle -7500403 true true 157 151 220 185
Rectangle -7500403 true true 94 189 148 233
Rectangle -7500403 true true 135 162 184 297
Circle -7500403 true true 219 76 28
Circle -7500403 true true 138 7 34
Circle -7500403 true true 67 93 30
Circle -7500403 true true 201 145 40
Circle -7500403 true true 69 193 40
Circle -2674135 true false 156 171 108

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

car sick
false
0
Polygon -7500403 true true 285 208 285 178 279 164 261 144 240 135 226 132 213 106 199 84 171 68 149 68 129 68 75 75 15 150 15 165 15 225 285 225 283 174 283 176
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 195 90 135 90 135 135 210 135 195 105 165 90
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58
Circle -2674135 true false 171 156 108

cat
false
0
Line -7500403 true 285 240 210 240
Line -7500403 true 195 300 165 255
Line -7500403 true 15 240 90 240
Line -7500403 true 285 285 195 240
Line -7500403 true 105 300 135 255
Line -16777216 false 150 270 150 285
Line -16777216 false 15 75 15 120
Polygon -7500403 true true 300 15 285 30 255 30 225 75 195 60 255 15
Polygon -7500403 true true 285 135 210 135 180 150 180 45 285 90
Polygon -7500403 true true 120 45 120 210 180 210 180 45
Polygon -7500403 true true 180 195 165 300 240 285 255 225 285 195
Polygon -7500403 true true 180 225 195 285 165 300 150 300 150 255 165 225
Polygon -7500403 true true 195 195 195 165 225 150 255 135 285 135 285 195
Polygon -7500403 true true 15 135 90 135 120 150 120 45 15 90
Polygon -7500403 true true 120 195 135 300 60 285 45 225 15 195
Polygon -7500403 true true 120 225 105 285 135 300 150 300 150 255 135 225
Polygon -7500403 true true 105 195 105 165 75 150 45 135 15 135 15 195
Polygon -7500403 true true 285 120 270 90 285 15 300 15
Line -7500403 true 15 285 105 240
Polygon -7500403 true true 15 120 30 90 15 15 0 15
Polygon -7500403 true true 0 15 15 30 45 30 75 75 105 60 45 15
Line -16777216 false 164 262 209 262
Line -16777216 false 223 231 208 261
Line -16777216 false 136 262 91 262
Line -16777216 false 77 231 92 261

cat sick
false
0
Line -7500403 true 285 240 210 240
Line -7500403 true 195 300 165 255
Line -7500403 true 15 240 90 240
Line -7500403 true 285 285 195 240
Line -7500403 true 105 300 135 255
Line -16777216 false 150 270 150 285
Line -16777216 false 15 75 15 120
Polygon -7500403 true true 300 15 285 30 255 30 225 75 195 60 255 15
Polygon -7500403 true true 285 135 210 135 180 150 180 45 285 90
Polygon -7500403 true true 120 45 120 210 180 210 180 45
Polygon -7500403 true true 180 195 165 300 240 285 255 225 285 195
Polygon -7500403 true true 180 225 195 285 165 300 150 300 150 255 165 225
Polygon -7500403 true true 195 195 195 165 225 150 255 135 285 135 285 195
Polygon -7500403 true true 15 135 90 135 120 150 120 45 15 90
Polygon -7500403 true true 120 195 135 300 60 285 45 225 15 195
Polygon -7500403 true true 120 225 105 285 135 300 150 300 150 255 135 225
Polygon -7500403 true true 105 195 105 165 75 150 45 135 15 135 15 195
Polygon -7500403 true true 285 120 270 90 285 15 300 15
Line -7500403 true 15 285 105 240
Polygon -7500403 true true 15 120 30 90 15 15 0 15
Polygon -7500403 true true 0 15 15 30 45 30 75 75 105 60 45 15
Line -16777216 false 164 262 209 262
Line -16777216 false 223 231 208 261
Line -16777216 false 136 262 91 262
Line -16777216 false 77 231 92 261
Circle -2674135 true false 186 186 108

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

cow skull
false
0
Polygon -7500403 true true 150 90 75 105 60 150 75 210 105 285 195 285 225 210 240 150 225 105
Polygon -16777216 true false 150 150 90 195 90 150
Polygon -16777216 true false 150 150 210 195 210 150
Polygon -16777216 true false 105 285 135 270 150 285 165 270 195 285
Polygon -7500403 true true 240 150 263 143 278 126 287 102 287 79 280 53 273 38 261 25 246 15 227 8 241 26 253 46 258 68 257 96 246 116 229 126
Polygon -7500403 true true 60 150 37 143 22 126 13 102 13 79 20 53 27 38 39 25 54 15 73 8 59 26 47 46 42 68 43 96 54 116 71 126

cow skull sick
false
0
Polygon -7500403 true true 150 90 75 105 60 150 75 210 105 285 195 285 225 210 240 150 225 105
Polygon -16777216 true false 150 150 90 195 90 150
Polygon -16777216 true false 150 150 210 195 210 150
Polygon -16777216 true false 105 285 135 270 150 285 165 270 195 285
Polygon -7500403 true true 240 150 263 143 278 126 287 102 287 79 280 53 273 38 261 25 246 15 227 8 241 26 253 46 258 68 257 96 246 116 229 126
Polygon -7500403 true true 60 150 37 143 22 126 13 102 13 79 20 53 27 38 39 25 54 15 73 8 59 26 47 46 42 68 43 96 54 116 71 126
Circle -2674135 true false 156 186 108

cylinder
false
0
Circle -7500403 true true 0 0 300

dog
false
0
Polygon -7500403 true true 300 165 300 195 270 210 183 204 180 240 165 270 165 300 120 300 0 240 45 165 75 90 75 45 105 15 135 45 165 45 180 15 225 15 255 30 225 30 210 60 225 90 225 105
Polygon -16777216 true false 0 240 120 300 165 300 165 285 120 285 10 221
Line -16777216 false 210 60 180 45
Line -16777216 false 90 45 90 90
Line -16777216 false 90 90 105 105
Line -16777216 false 105 105 135 60
Line -16777216 false 90 45 135 60
Line -16777216 false 135 60 135 45
Line -16777216 false 181 203 151 203
Line -16777216 false 150 201 105 171
Circle -16777216 true false 171 88 34
Circle -16777216 false false 261 162 30

dog sick
false
0
Polygon -7500403 true true 300 165 300 195 270 210 183 204 180 240 165 270 165 300 120 300 0 240 45 165 75 90 75 45 105 15 135 45 165 45 180 15 225 15 255 30 225 30 210 60 225 90 225 105
Polygon -16777216 true false 0 240 120 300 165 300 165 285 120 285 10 221
Line -16777216 false 210 60 180 45
Line -16777216 false 90 45 90 90
Line -16777216 false 90 90 105 105
Line -16777216 false 105 105 135 60
Line -16777216 false 90 45 135 60
Line -16777216 false 135 60 135 45
Line -16777216 false 181 203 151 203
Line -16777216 false 150 201 105 171
Circle -16777216 true false 171 88 34
Circle -16777216 false false 261 162 30
Circle -2674135 true false 126 186 108

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

ghost
false
0
Polygon -7500403 true true 30 165 13 164 -2 149 0 135 -2 119 0 105 15 75 30 75 58 104 43 119 43 134 58 134 73 134 88 104 73 44 78 14 103 -1 193 -1 223 29 208 89 208 119 238 134 253 119 240 105 238 89 240 75 255 60 270 60 283 74 300 90 298 104 298 119 300 135 285 135 285 150 268 164 238 179 208 164 208 194 238 209 253 224 268 239 268 269 238 299 178 299 148 284 103 269 58 284 43 299 58 269 103 254 148 254 193 254 163 239 118 209 88 179 73 179 58 164
Line -16777216 false 189 253 215 253
Circle -16777216 true false 102 30 30
Polygon -16777216 true false 165 105 135 105 120 120 105 105 135 75 165 75 195 105 180 120
Circle -16777216 true false 160 30 30

ghost sick
false
0
Polygon -7500403 true true 30 165 13 164 -2 149 0 135 -2 119 0 105 15 75 30 75 58 104 43 119 43 134 58 134 73 134 88 104 73 44 78 14 103 -1 193 -1 223 29 208 89 208 119 238 134 253 119 240 105 238 89 240 75 255 60 270 60 283 74 300 90 298 104 298 119 300 135 285 135 285 150 268 164 238 179 208 164 208 194 238 209 253 224 268 239 268 269 238 299 178 299 148 284 103 269 58 284 43 299 58 269 103 254 148 254 193 254 163 239 118 209 88 179 73 179 58 164
Line -16777216 false 189 253 215 253
Circle -16777216 true false 102 30 30
Polygon -16777216 true false 165 105 135 105 120 120 105 105 135 75 165 75 195 105 180 120
Circle -16777216 true false 160 30 30
Circle -2674135 true false 156 171 108

heart
false
0
Circle -7500403 true true 152 19 134
Polygon -7500403 true true 150 105 240 105 270 135 150 270
Polygon -7500403 true true 150 105 60 105 30 135 150 270
Line -7500403 true 150 270 150 135
Rectangle -7500403 true true 135 90 180 135
Circle -7500403 true true 14 19 134

heart sick
false
0
Circle -7500403 true true 152 19 134
Polygon -7500403 true true 150 105 240 105 270 135 150 270
Polygon -7500403 true true 150 105 60 105 30 135 150 270
Line -7500403 true 150 270 150 135
Rectangle -7500403 true true 135 90 180 135
Circle -7500403 true true 14 19 134
Circle -2674135 true false 171 156 108

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

key
false
0
Rectangle -7500403 true true 90 120 300 150
Rectangle -7500403 true true 270 135 300 195
Rectangle -7500403 true true 195 135 225 195
Circle -7500403 true true 0 60 150
Circle -16777216 true false 30 90 90

key sick
false
0
Rectangle -7500403 true true 90 120 300 150
Rectangle -7500403 true true 270 135 300 195
Rectangle -7500403 true true 195 135 225 195
Circle -7500403 true true 0 60 150
Circle -16777216 true false 30 90 90
Circle -2674135 true false 156 171 108

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

leaf sick
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195
Circle -2674135 true false 141 171 108

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

monster
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270

monster sick
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270
Circle -2674135 true false 141 141 108

moon
false
0
Polygon -7500403 true true 175 7 83 36 25 108 27 186 79 250 134 271 205 274 281 239 207 233 152 216 113 185 104 132 110 77 132 51

moon sick
false
0
Polygon -7500403 true true 160 7 68 36 10 108 12 186 64 250 119 271 190 274 266 239 192 233 137 216 98 185 89 132 95 77 117 51
Circle -2674135 true false 171 171 108

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

person sick
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Circle -2674135 true false 178 163 95

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

star sick
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108
Circle -2674135 true false 156 171 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

target sick
true
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60
Circle -2674135 true false 163 163 95

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

wheel sick
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
Circle -2674135 true false 156 156 108

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
random-seed 3
setup-clear
infect
repeat 100 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="3" runMetricsEveryStep="true">
    <setup>setup-clear
infect</setup>
    <go>go</go>
    <metric>days</metric>
    <metric>nb-deaths</metric>
    <enumeratedValueSet variable="ic-places-growth-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confinement">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-sed-to-die-init">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="%detected">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="j-stop-and-go">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="having-mask-growth">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-sed-to-go-init">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobiles-part">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-people">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-mob-to-die-init">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensive-care-places">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="desobedience-degrowth">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="confinement-duration">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infected-people-trigger">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-protection-rate">
      <value value="98"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ticks-a-day">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="desobediance-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-and-go?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="having-mask-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contagiousness">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="progressive-unconfining-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="p-mob-to-go-init">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
