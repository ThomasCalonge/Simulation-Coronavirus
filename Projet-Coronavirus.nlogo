;;;;;;;;;;;;;;;;;;
;; Declarations ;;
;;;;;;;;;;;;;;;;;;

globals [
  ;; when multiple runs are recorded in the plot, this
  ;; tracks what run number we're on
  run-number
  ;; counter used to keep the model running for a little
  ;; while after the last turtle gets infected
  delay
  nb-sick               ;; int - count turtles with [ is-sick? ]
  nb-incubating         ;; int - count turtles with [ is-incubating? ]
  nb-immune             ;; int - count turtles with [ is-immune? ]
  nb-in-intensive-care  ;; int - count turtles with [ is-immune? ]

  nb-confined           ;; int - count turtles with [ is-confined? ]
  nb-rebels             ;; int - count turtles with [ is-rebel? ]
  nb-has-mask           ;; int - count turtles with [ has-mask? ]
  nb-needs-care         ;; int - count turtles with [ needs-care? ]

  nb-sedentaries        ;; int - count sedentaries
  nb-mobiles            ;; int - count sedentaries

  nb-deaths             ;; int - number of deaths
  nb-alives             ;; int - number of alive

  nb-free-ic-places     ;; int - available intensive care places
  ic-places-growth      ;; int - intensive care places growth rate

  in-confinement?       ;; bool - whether confinement is or not
  delay-unconfinement   ;; int - confinement duration
  already-happened?     ;; bool - whether confinement has been or not yet

  ticks-a-day           ;; int - how many tick happen per day
  growth-start?         ;; bool - certain values are evolving when confinement has started
]

breed [ sedentaries sedentary ]
breed [ mobiles mobile ]

;; patches variables
patches-own [
  dying-time            ;; turtles own timer for incubating, sick or dying.
  has-germs?            ;; bool - whether there are germs on a patch
  germs-amount          ;; int - 0-100 amount of germs on a patch
]

;; turtles variables
turtles-own [
  has-mask?             ;; bool - whether turtle has a mask
  is-rebel?             ;; bool - whether turtle is a rebel
  is-sick?              ;; bool - whether turtle is sick
  needs-care?           ;; bool - whether turtle needs to be in intensive care
  in-intensive-care?    ;; bool - whether turtle is in intensive care
  is-incubating?        ;; bool - whether turtle is incubating
  is-immune?            ;; bool - whether turtle is immune
  is-confined?          ;; bool - whether turtle is confined
  count-time            ;; int - timer for incubating, being sick or dying
  proba-to-die          ;; int - death probability - probabilities are increasing if turtle is not in intensive care
  proba-to-go           ;; ??? - each 3 days, probability to go for the turtle are increasing
]

;; sedentary turtles variables
sedentaries-own [
  is-work-done?         ;; bool - whether turtle has been to work today
  house                 ;; patch - turtle spawn patch
  work                  ;; patch - turtle work patch at a random radius between 3-20 patches away
]

;; mobile turtle variables
mobiles-own [
  road-done             ;; int - change orientation every 5 ticks
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
  set run-number                 (run-number + 1)
  setup-world
end

to setup-world
  ;; All values to 0.
  set-default-shape turtles "android"

  set nb-sick                    0
  set nb-incubating              0
  set nb-immune                  0
  set nb-in-intensive-care       0
  set nb-has-mask                0
  set nb-confined                0
  set nb-rebels                  0
  set nb-needs-care              0
  set nb-sedentaries             0
  set nb-mobiles                 0
  set nb-deaths                  0
  set delay                      0
  set delay-unconfinement        0
  set ticks-a-day                12
  set growth-start?              false
  set already-happened?          false
  set in-confinement?            false
  set nb-alives                  nb-people
  set nb-free-ic-places          intensive-care-places
  ask patches [ set has-germs?   false ]
  create-people
  reset-ticks
end




to infect
  ask one-of turtles [ get-sick ]
end



;; methods to choose the turtles who will be confined
to confine-people
  set delay-unconfinement        0
  ;; reset number of confined in model stop and go.
  if (already-happened? and stop-and-go?) [
    ask turtles with [ is-confined? ] [
      set is-confined?           false
      set nb-confined            (nb-confined - 1)
    ]
  ]
  repeat nb-sedentaries * 0.9 [
    ask one-of sedentaries with [ is-confined? = false ] [
      set is-confined?           true
      set nb-confined            (nb-confined + 1)
    ]
  ]
end

;; unconfine people
;; give a mask to some people
to unconfine-people
  if (not already-happened?) [
    repeat nb-alives * (having-mask-rate / 100) [
      ask one-of turtles with [ has-mask? = false ] [
        set has-mask?            true
        set nb-has-mask          (nb-has-mask + 1)
      ]
    ]
  ]
  set already-happened?          true
  set delay-unconfinement        0
end

to unconfine-people-progressive
  if (delay-unconfinement mod (7 * ticks-a-day) = 0) [
    repeat nb-confined * (progressive-unconfining-rate / 100) [
      ifelse (nb-confined > 0)
      [
        ask one-of turtles with [is-confined? and not is-sick?] [
          set is-confined?       false
          set nb-confined        (nb-confined - 1)
        ]
      ]
      [ stop ]
    ]
  ]
end

to create-people
  create-sedentaries nb-people * 0.95 [

    set nb-sedentaries          (nb-sedentaries + 1)

    let x                       random-pxcor
    let y                       random-pycor

    ;; put androids on patch centers
    setxy x y

    set house                   patch-here
    set work                    one-of patches in-radius ((random 17) + 3)

    set color                   gray

    ;; start value
    set count-time              1

    set is-sick?                false
    set is-incubating?          false
    set needs-care?             false
    set is-immune?              false
    set in-intensive-care?      false
    set is-work-done?           false

    ;; confinement related boolean value.
    set has-mask?               false
    set is-confined?            false

    set proba-to-die            35
    set proba-to-go             10

    ifelse(random 100 < desobediance-rate)
    [
      set is-rebel?             true
      set nb-rebels             (nb-rebels + 1)
    ]
    [ set is-rebel?             false ]
  ]
  create-mobiles nb-people * 0.05 [
    set nb-mobiles              (nb-mobiles + 1)

    let x                       random-pxcor
    let y                       random-pycor

    ;; put androids on patch centers
    setxy x y

    set color                   gray
    set heading                 90 * random 4

    ;; start value
    set count-time              1

    ;; all boolean value to false, means the agent is sane
    set is-sick?                false
    set is-incubating?          false
    set needs-care?             false
    set in-intensive-care?      false
    set is-immune?              false

    set is-confined?            false
    set has-mask?               false

    set proba-to-die            35
    set proba-to-go             10

    ifelse (random 100 < desobediance-rate)
    [
      set is-rebel?             true
      set nb-rebels             (nb-rebels + 1)
    ]
    [ set is-rebel?             false ]
  ]
end


to croissance
  if (in-confinement? or (nb-needs-care > nb-free-ic-places)) [
    let nb-no-mask              (nb-alives - nb-has-mask)
    if (nb-no-mask > 0) [
      repeat nb-no-mask * (having-mask-growth / 100) [
        if ((nb-alives - nb-has-mask) > 0) [
          ask one-of turtles with [ not has-mask? ] [
            set has-mask?       true
            set nb-has-mask     (nb-has-mask + 1)
          ]
        ]
      ]
    ]
  ]

  set ic-places-growth        (ic-places-growth + (intensive-care-places * (ic-places-growth-rate / 100)))
  let nb-more-ic-places       (intensive-care-places * (ic-places-growth-rate / 100))
  set nb-free-ic-places       (nb-free-ic-places + nb-more-ic-places)

  ;; Rebels number degrowth
  if (nb-rebels > 0) [
    repeat nb-rebels * (desobedience-degrowth / 100) [
      if (nb-rebels > 0) [
        ask one-of turtles with [ is-rebel? ] [
          set is-rebel?         false
          set nb-rebels         (nb-rebels - 1)
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Functions ;;
;;;;;;;;;;;;;;;;;;;;;;;

to go
  ;; in order to extend the plot for a little while
  ;; after all the turtles are infected...
  if (nb-sick = nb-alives) [
    set delay                   (delay + 1)
  ]
  if (delay > 50) [
    stop
  ]

  ;; each week, there an increase values of things
  ;; we are not in a static model.
  if (growth-start? and ticks mod (7 * ticks-a-day) = 0) [
    croissance
  ]

  if (already-happened? and not in-confinement?) [
    unconfine-people-progressive
  ]

  if (in-confinement? = true or already-happened?) [
    set delay-unconfinement     (delay-unconfinement + 1)
  ]

  ;; ticks-a-day multiplied by the days needed for deconfinement.
  ;; the deconfinement begins
  if confinement and (delay-unconfinement > confinement-duration * ticks-a-day) and in-confinement? and (not already-happened? or stop-and-go?) [
    set in-confinement?         false
    unconfine-people
  ]

  ;; the confinement begins
  if confinement and (nb-sick * (%detected / 100) > nb-alives * (infected-people-trigger / 100)) and not in-confinement? and (not already-happened? or (stop-and-go? and delay-unconfinement > (j-stop-and-go * ticks-a-day))) [
    set growth-start?           true
    set in-confinement?         true
    confine-people
  ]

  ;; now for the main stuff;
  change-color
  sickness-evolution
  androids-wander

  ;; infected people spit their lungs on surfaces
  ask turtles with [ (is-incubating? and count-time > 80) or (is-sick? and not in-intensive-care?) ] [
    spread-disease-turtle
  ]

  ;; germs spread virus
  ask patches with [ has-germs? ] [
    spread-disease-patch
  ]

  tick
end

;; manage each object color
to change-color
  ask turtles [
    if (is-immune? = true) [ set color blue ]
    if (is-incubating? = true) [ set color white ]
    if (is-sick? = true) [ set color green ]
    if (needs-care? = true) [ set color red ]
  ]
  ask patches [
    if (has-germs? = true)[ set pcolor 51 ]
    if (has-germs? = false) [ set pcolor black ]
  ]
end

to sickness-evolution

  ;; each tick kill virus
  ask patches with [ has-germs? ] [
    if (germs-amount = 0) [
      set has-germs?            false
    ]
    ;; germ is aging
    set dying-time              (dying-time + 1)
    ;; germs die outside an host
    if(dying-time = 2) [
      set dying-time            0
      set germs-amount          (germs-amount - 20)
    ]
  ]



  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; PROCEDURE WHEN IN INCUBATION  ;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;; incubation after an elpased time

  ask turtles [
    ifelse (is-incubating?)
    [
      ifelse (count-time mod (14 * ticks-a-day) = 0)
      [
        set is-incubating?      false
        set nb-incubating       (nb-incubating - 1)
        set is-sick?            true
        set nb-sick             (nb-sick + 1)
        set count-time          1
      ]
      [ set count-time          (count-time + 1) ]
    ]
    [
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; PROCEDURE WHEN IN SICKNESS  ;;
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      ifelse (is-sick? and not needs-care? and not in-intensive-care?)
      [
        if (count-time mod (7 * ticks-a-day) = 0) [
          set is-immune?          true
          set nb-immune           (nb-immune + 1)
          set is-sick?            false
          set nb-sick             (nb-sick - 1)
        ]
        ;; Every 12 ticks, turtle rolls dice to go
        ;; in intensive care or not with a 1% risk
        ifelse ((count-time mod ticks-a-day = 0) and (random 100 < 1))
        [
          set needs-care?         true
          set nb-needs-care       (nb-needs-care + 1)
          set count-time          1
        ]
        [ set count-time          (count-time + 1) ]
      ]
      [
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; PROCEDURE WHEN IN INTENSIVE CARE  ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        if (needs-care?) [
          let is-day?                       (count-time mod ticks-a-day) = 0
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
            set proba-to-go                 35
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
                if (is-confined? = true)    [ set nb-confined (nb-confined - 1) ]
                if (is-rebel? = true)       [ set nb-rebels (nb-rebels - 1) ]
                if (is-sick? = true)        [ set nb-sick (nb-sick - 1) ]
                if (has-mask? = true)       [ set nb-has-mask (nb-has-mask - 1) ]
                if (needs-care? = true)     [ set nb-needs-care (nb-needs-care - 1) ]
                die
              ]
              [ set proba-to-die (proba-to-die + 5) ]
            ]
            [
              ifelse (random 100 < proba-to-die)
              [
                set nb-deaths               (nb-deaths + 1)
                set nb-alives               (nb-alives - 1)
                if (breed = sedentaries)    [ set nb-sedentaries (nb-sedentaries - 1) ]
                if (breed = mobiles)        [ set nb-mobiles (nb-mobiles - 1) ]
                if (is-confined? = true)    [ set nb-confined (nb-confined - 1) ]
                if (is-rebel? = true)       [ set nb-rebels (nb-rebels - 1) ]
                if (is-sick? = true)        [ set nb-sick (nb-sick - 1) ]
                if (has-mask? = true)       [ set nb-has-mask (nb-has-mask - 1) ]
                if (needs-care? = true)     [ set nb-needs-care (nb-needs-care - 1) ]
                die
              ]
              [ set proba-to-die (proba-to-die + 15) ]
            ]
          ]
          set count-time (count-time + 1)
        ]
      ]
    ]
  ]
end

;; controls the motion of the androids
to androids-wander
  ask turtles [
    ifelse (breed = sedentaries and needs-care? = false)
    [

      ;; 1% probability to go abroad
      if ((random 100 > 98) and (is-confined? = false) and (ticks mod 20 = 0)) [
        setxy random-pxcor random-pycor
      ]

      ;; Commuting back to home
      if (patch-here = work) [
        set is-work-done? true
      ]

      ;; Commuting to work
      if (patch-here = house) [
        set is-work-done? false
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
      if (breed = mobiles and needs-care? = false) [
        if (road-done mod 5 = 0) [
          rt (random 180) - 90
        ]
        set road-done road-done + 1
        fd 3
      ]
    ]
  ]
end

;; turtle procedure
;; if the turtle has a mask, %chance of impact-of-mask.
to spread-disease-turtle
  if (has-mask? and random 100 < mask-protection-rate) [
    stop
  ]

  ;; Neighbors talking face-to-face
  if (in-confinement? = false or is-rebel?) [
    ;; 20% for an encounter between two turtles.
    if (random 100 < 20) [
      if (count other turtles-here != 0) [
        ask one-of other turtles-here [ maybe-get-sick ]
      ]
    ]
  ]

  ask patch-here [
    if (random 100 > 50) [
      set has-germs? true
      set germs-amount 100
      set dying-time 0
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
  if (not is-sick? and not is-immune? and not needs-care? and not is-incubating? and not is-confined? and random 100 < contagiousness)
  [ get-sick ]
end

;; turtle procedure
;; > set the appropriate variables to make this turtle sick
to get-sick
  set is-incubating? true
  set nb-incubating nb-incubating + 1
end

;; Projet de recherche M1 Informatique CILS, Guillaume COQUARD et Thomas CALONGE -- Année 2020
@#$#@#$#@
GRAPHICS-WINDOW
253
10
1042
800
-1
-1
2.163435
1
10
1
1
1
0
0
0
1
-180
180
-180
180
1
1
1
ticks
10.0

BUTTON
8
52
110
85
setup/clear
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
129
111
162
NIL
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
10
195
242
228
contagiousness
contagiousness
0
100
50.0
1
1
%
HORIZONTAL

PLOT
10
230
242
407
Incubating / Sick
time
people
0.0
10.0
0.0
6.0
true
false
"" ""
PENS
"sick" 1.0 0 -2674135 true "create-temporary-plot-pen word \"run \" run-number\nset-plot-pen-color item (run-number mod 5)\n                        [blue red green orange violet]" "plot nb-sick"
"is-incubating" 1.0 0 -8732573 true "" "plot nb-incubating"

SLIDER
9
10
241
43
nb-people
nb-people
1
100000
10000.0
100
1
NIL
HORIZONTAL

MONITOR
130
409
242
454
Sick People
nb-sick
0
1
11

BUTTON
8
87
110
120
setup/keep
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
124
96
221
114
keeps old plots
11
0.0
0

TEXTBOX
124
62
221
80
clears old plots\n
11
0.0
0

SLIDER
452
810
544
843
step-size
step-size
1
5
5.0
1
1
NIL
HORIZONTAL

BUTTON
120
129
222
162
NIL
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
1051
10
1304
43
intensive-care-places
intensive-care-places
10
1000
10.0
10
1
NIL
HORIZONTAL

PLOT
1051
214
1304
413
Intensive Care Places
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot nb-free-ic-places"

PLOT
1051
612
1305
799
Alives / Deaths
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"deaths" 1.0 0 -2674135 true "create-temporary-plot-pen word \"run \" run-number\nset-plot-pen-color item (run-number mod 5)\n                        [blue red green orange violet]" "plot nb-deaths"

PLOT
1051
415
1305
610
People in need of Intensive Care
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot nb-needs-care"
"pen-1" 1.0 0 -5298144 true "" "plot intensive-care-places + ic-places-growth"

MONITOR
10
409
128
454
Incubating People
nb-incubating
17
1
11

SWITCH
11
485
243
518
confinement
confinement
0
1
-1000

SLIDER
11
649
243
682
infected-people-trigger
infected-people-trigger
0
5
0.369
0.001
1
NIL
HORIZONTAL

SLIDER
11
567
243
600
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
567
809
799
842
desobediance-rate
desobediance-rate
0
100
33.0
1
1
NIL
HORIZONTAL

MONITOR
11
520
243
565
NIL
in-confinement?
17
1
11

MONITOR
11
810
166
855
Not Confined People
nb-alives - nb-confined
17
1
11

SLIDER
809
809
1041
842
having-mask-rate
having-mask-rate
0
100
40.0
1
1
NIL
HORIZONTAL

MONITOR
1051
809
1229
854
People Having a Mask
nb-has-mask
17
1
11

SLIDER
11
766
243
799
progressive-unconfining-rate
progressive-unconfining-rate
1
100
20.0
1
1
NIL
HORIZONTAL

MONITOR
11
602
243
647
Days since Confinement
int (delay-unconfinement / 12)
17
1
11

SLIDER
1051
80
1304
113
mask-protection-rate
mask-protection-rate
0
100
93.0
1
1
NIL
HORIZONTAL

MONITOR
1050
166
1303
211
People who need care
nb-needs-care
17
1
11

SLIDER
11
731
243
764
%detected
%detected
0
100
80.0
1
1
NIL
HORIZONTAL

SWITCH
255
810
427
843
stop-and-go?
stop-and-go?
1
1
-1000

MONITOR
11
684
243
729
Triggering Infected People Amount
nb-people * (infected-people-trigger / 100)
0
1
11

SLIDER
255
846
427
879
j-stop-and-go
j-stop-and-go
1
31
14.0
1
1
NIL
HORIZONTAL

SLIDER
809
843
1041
876
having-mask-growth
having-mask-growth
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
567
843
799
876
desobedience-degrowth
desobedience-degrowth
0
100
32.0
1
1
NIL
HORIZONTAL

SLIDER
1051
45
1304
78
ic-places-growth-rate
ic-places-growth-rate
0
100
10.0
1
1
NIL
HORIZONTAL

MONITOR
169
810
243
855
Rebels
nb-rebels
17
1
11

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
