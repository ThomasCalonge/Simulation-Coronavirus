;;;;;;;;;;;;;;;;;;
;; Declarations ;;
;;;;;;;;;;;;;;;;;;

globals
[
  ;; number of turtles that are sick
  num-sick
  ;; when multiple runs are recorded in the plot, this
  ;; tracks what run number we're on
  run-number
  ;; counter used to keep the model running for a little
  ;; while after the last turtle gets infected
  delay
  nb-place-disponible
  deaths
  ;; when the confinement is declared
  confinement?
  delay-deconfinement
  ;; boolean value to check if we already confined,deconfined the population.
  only-once

  ticks-a-day ;; constant value to define how many ticks is a full day.
  debut-croissance? ;; when the confinement starts, all values are growing up.

  nb-lit-croissant ;; used for both the plot and the nb-lit-disponible
]

breed [ sedentaires sedentaire ]
breed [ routiers routier ]

;; patches variables
patches-own
[
  dying-time ;; turtles own timer for incubating, sick or dying.
  germes? ;; whether there is a presence of germs on a patch (true/false)
  germes ;; from 0-100 germs spread on a patch.
]

;; turtles variables
turtles-own
[
  rebel?;; turtles can be a rebel ;)
  masque? ;; whether the turtle has a mask (true/false)

  count-time ;; turtles own timer for incubating, sick or dying.
  reanimation? ;; whether turtle have access to a bed in hospital (true/false)
  incubation? ;; whether turtle is incubating (true/false)
  malade?    ;; whether turtle is sick (true/false)
  grave?     ;; whether turtle needs reanimation (true/false)
  immunise?  ;; whether turtle  is immune to the sickness (true/false)
  confiner? ;; whether turtle state is confined (true/false)

  chance-to-die ;; if the turtle is in reanimation, the chances are increasing without it.
  chance-to-go ;; each 3 days, the chance to go for the turtle are increasing.
]
sedentaires-own [
  workdone? ;; if the turtle has been to work or replenish to house
  house ;; all turtles spawn at his house
  work ;; his work is at a random radius between 3-20 patches away
]
routiers-own [
  road-done ;; whenever an agent has done 5 tick, he change his orientation
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
  set run-number run-number + 1
  setup-world
end

to setup-world
  ;; All values to 0.
  set-default-shape turtles "android"
  set debut-croissance? false
  set num-sick 0
  set delay 0
  set delay-deconfinement 0
  set only-once false
  set confinement? false
  ask patches [ set germes? false ]

  set ticks-a-day 12
  create-population
  set nb-place-disponible max-hopital
  reset-ticks
end

to infect
  ask one-of turtles [ get-sick ]
end

to confinement-population
  set delay-deconfinement 0

  if (only-once and stop-and-go?) [
    ask turtles with [ confiner? ] [ set confiner? false ]
  ] ;; reset number of confined in model stop and go.

  repeat count sedentaires * 0.9 [
    ask one-of sedentaires with [ confiner? = false ]
    [ set confiner? true ]
  ]
end ;; methods to choose the turtles who will be confined

to deconfinement-population
  if (not only-once) [
    repeat num-population * (%population-with-mask / 100) [
      ask one-of turtles with [ masque? = false ] [ set masque? true ]
    ]
  ]

  set only-once true
  set delay-deconfinement 0
end ;; setup the deconfinement, and put mask on people

to deconfinement-population-progressive
  if (delay-deconfinement mod (7 * ticks-a-day) = 0) ;; day multiplied by the tick needed for a day
  [

    repeat count turtles with [ confiner? ] * (%population-deconfined-per-week / 100) [
      ifelse (count turtles with [ confiner? ] > 0) [
        ask one-of turtles with [ confiner? and not malade? ] [ set confiner? false ]
      ]
      [ stop ]
    ]
  ]
end

to create-population
  create-sedentaires num-population * 0.95
  [
    let x random-pxcor
    let y random-pycor

    ;; put androids on patch centers
    setxy x y

    set house patch-here
    set work one-of patches in-radius ((random 17)
      + 3)

    set color gray

    ;; start value
    set count-time 1

    ;; all boolean value to false, means the agent is sane
    set malade? false
    set incubation? false
    set grave? false
    set immunise? false
    set reanimation? false
    set workdone? false
    ;; confinement relate boolean value.
    set masque? false
    set confiner? false

    set chance-to-die 35
    set chance-to-go 10

    ifelse(random 100 < taux-desobeissance) [
      set rebel? true
    ]
    [
      set rebel? false
    ]
  ]

  create-routiers num-population * 0.05
  [
    let x random-pxcor
    let y random-pycor

    ;; put androids on patch centers
    setxy x y

    set color gray
    set heading 90 * random 4

    ;; start value
    set count-time 1

    ;; all boolean value to false, means the agent is sane
    set malade? false
    set incubation? false
    set grave? false
    set reanimation? false
    set immunise? false

    set confiner? false
    set masque? false

    set chance-to-die 35
    set chance-to-go 10

    ifelse(random 100 < taux-desobeissance) [
      set rebel? true
    ]
    [
      set rebel? false
    ]
  ]
end

to croissance

  if(only-once) [
    let nb-mask count turtles with [ not masque? ]
    if nb-mask > 0 [
      repeat nb-mask * (%croissance-mask / 100) [
        if (count turtles with [ not masque? ] > 0) [
          ask one-of turtles with [ not masque? ] [ set masque? true ]
        ]
      ]
    ]
  ]
  ;; Croissance du port du masque

  set nb-lit-croissant nb-lit-croissant + (max-hopital * (%croissance-lit-reanimation / 100)) ;; used for the plot

  let nb-lit-suppl (max-hopital * (%croissance-lit-reanimation / 100))
  set nb-place-disponible nb-place-disponible + nb-lit-suppl
  ;; Croissance des lit d'hopitaux

  let nb-rebels count turtles with [ rebel? ]
  if nb-rebels > 0 [
    repeat nb-rebels * (%decroissance-desobeissance / 100) [
      if (count turtles with [ rebel? ] > 0) [
        ask one-of turtles with [ rebel? ] [ set rebel? false ]
      ]
    ]
  ]
  ;; Decroissance des gens desobeissant

end

;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Functions ;;
;;;;;;;;;;;;;;;;;;;;;;;

to go
  ;; in order to extend the plot for a little while
  ;; after all the turtles are infected...
  if num-sick = count turtles
  [ set delay delay + 1  ]
  if delay > 50
  [ stop ]

  if (debut-croissance? and ticks mod (7 * ticks-a-day) = 0) [
    croissance
  ] ;; each week, there an increase values of things, we are not in a static model.

  if (only-once and not confinement?) [ deconfinement-population-progressive ]

  if (confinement? = true or only-once) [ set delay-deconfinement delay-deconfinement + 1 ]

  if confinement and (delay-deconfinement > j-deconfinement * ticks-a-day) and confinement? and (not only-once or stop-and-go?) [ ;; ticks-a-day multiplied by the days needed for deconfinement.
    set confinement? false deconfinement-population
  ] ;; the deconfinement begins

  if confinement and (num-sick * (%detected / 100) > num-population * ( %population-needed-to-start / 100)) and not confinement? and (not only-once or (stop-and-go? and delay-deconfinement > (j-stop-and-go * ticks-a-day))) [
    set debut-croissance? true
    set confinement? true confinement-population
  ] ;; the confinement begins


  ;; now for the main stuff;
  change-color
  sickness-evolution
  androids-wander

  ;; infected people spit their lungs on surfaces
  ask turtles with [ incubation? and count-time > 80 ] [ spread-disease ]

  ;; sick people spit their lungs on surfaces
  ask turtles with [ malade? ] [ spread-disease ]

  ;; germs spread virus
  ask patches with [ germes? ] [ spread-disease-patch ]

  set num-sick count turtles with [ malade? ]

  tick
end

;; manage each object color
to change-color
  ask turtles with [ immunise? ] [ set color blue ]
  ask turtles with [ incubation? ] [ set color white ]
  ask turtles with [ malade? ] [ set color green ]
  ask turtles with [ grave? ] [ set color red ]
  ask patches with [ germes? ] [ set pcolor 51 ]
  ask patches with [ germes? = false ] [ set pcolor black ]
end

to sickness-evolution
  ;; each tick kill virus
  ask patches with [ germes? ] [
    if ( germes = 0 )
    [ set germes? false ]
    ;; germ is aging
    set dying-time dying-time + 1
    ;; germs die outside an host
    if(dying-time = 2)
    [
      set dying-time 0
      set germes germes - 20
    ]
  ]

  ;; -----------------------------------
  ;; -- PROCEDURE WHEN IN INCUBATION  --
  ;; -----------------------------------

  ;; incubation after an elpased time
  ask turtles with [ incubation? ]
  [
    ifelse ( count-time mod (14 * ticks-a-day) = 0 )
    [
      set incubation? false
      set malade? true
      set count-time 1
    ]
    [ set count-time count-time + 1 ]
  ]

  ;; -----------------------------------
  ;; --   PROCEDURE WHEN IN SICKNESS  --
  ;; -----------------------------------

  ask turtles with [ malade? ]
  [
    if ( count-time mod (7 * ticks-a-day) = 0)
    [
      set malade? false
      set immunise? true
    ]
    ifelse ( (count-time mod ticks-a-day = 0) and random 100 < 1 ) ;; Tous les 12 ticks (1 journée), l'agent tire un jet aléatoire il a 1% de chance d'allez en réanimation.
    [
      set grave? true
      set malade? false
      set count-time 1
    ]
    [ set count-time count-time + 1 ]
  ] ;; 5% risk to get in intensive care


  ;; -----------------------------------
  ;; -- PROCEDURE WHEN IN REANIMATION --
  ;; -----------------------------------
  ask turtles with [ grave? ]
  [

    let is-day? (count-time mod ticks-a-day) = 0
    let is-three-days? (count-time mod (ticks-a-day * 3)) = 0

    if (is-three-days?) [
      ifelse (random 100 < chance-to-go)
    [
      if (reanimation?) [
        set nb-place-disponible nb-place-disponible + 1
        set reanimation? false
      ]

      set grave? false
      set immunise? true

      stop
    ]

    [
      ifelse (reanimation?) [
        set chance-to-go chance-to-go + 15
      ]

      [
        set chance-to-go chance-to-go + 5
      ]
    ]
    ]


    ;; taking one intensive care slot
    if ( nb-place-disponible > 0 and not reanimation?)
    [
      set chance-to-die 5
      set chance-to-go 35
      set nb-place-disponible nb-place-disponible - 1
      set reanimation? true
    ]

    if ( is-three-days? )
    [
      ifelse (reanimation?)
      [

        ifelse ( random 100 < chance-to-die )
        [
          set deaths deaths + 1
          set nb-place-disponible nb-place-disponible + 1

          die
        ] ;; 5% risk of dying if the agent as an instensive care slot

        [
          set chance-to-die chance-to-die + 5
        ]
      ]
      [
        ifelse ( random 100 < chance-to-die )
          [
            set deaths deaths + 1

            die
        ]
        [
          set chance-to-die chance-to-die + 15
        ]
      ]
    ] ;; 35% increasing by the time, chance of risk of dying if no slot in hospital
    set count-time count-time + 1
  ] ;; 20% risk of dying in intensive care
end

;; controls the motion of the androids
to androids-wander
  ask sedentaires with [ grave? = false ]
  [
    ;; 1% probability to go abroad
    if ( (random 100 > 98) and (confiner? = false) and (ticks mod 20 = 0))
    [ setxy random-pxcor random-pycor ]

    ;; Commuting back to home
    if ( patch-here = work )
    [ set workdone? true ]

    ;; Commuting to work
    if ( patch-here = house )
    [ set workdone? false ]

    ;; face direction
    ifelse ( workdone? and not confiner?)
    [ face house fd 1 ]
    [ face work fd 1 ]

    ;; returns home
    if (patch-here != house and confiner?)
    [ move-to house]

    if ( confiner? and (ticks mod 5 = 0) and (patch-here = house) and rebel? ) [ ;; Si un citoyen est ne respect pas le confinement, alors il va se promener autour de sa maison
      rt 45 * random 8
      fd 1
    ]
  ]

  ask routiers with [ grave? = false ]
  [
    if ( road-done = 5 )
    [
      rt (random 180) - 90
      set road-done 0
    ]
    set road-done road-done + 1
    fd 3
  ]
end

to spread-disease ;; turtle procedure
  if masque? and random 100 < %impact-of-mask [ stop ] ;; if the turtle has a mask, %chance of impact-of-mask.

  if ( confinement? = false or rebel? ) [ ;; Neighbors talking face-to-face
    if (random 100 < 20 ) ;; 20% for an encounter between two turtles.
      [
        if (count other turtles-here != 0) [ask one-of other turtles-here [ maybe-get-sick ] ]
    ]
  ]

  ask patch-here
  [
    if ( random 100 > 50 )
    [
      set germes? true
      set germes 100
      set dying-time 0
    ]
  ]

end

to spread-disease-patch ;; patch procedure
  ;; if a turtle touches a surface, then it'll be infected, depending on germ rate
  if ( random 100 > germes / 2 )
  [ ask turtles-here [ maybe-get-sick ] ]
end

to maybe-get-sick ;; turtle procedure
  ;; roll the dice and maybe get sick
  if ( not malade? ) and ( random 100 < infection-chance ) and confiner? = false
  [ get-sick ]
end

;; set the appropriate variables to make this turtle sick
to get-sick ;; turtle procedure
  if ( not malade? ) and ( not incubation? ) and ( not grave? ) and ( not immunise? )
  [ set incubation? true ]
end

;; Projet de recherche M1 Informatique CILS, Guillaume COQUARD et Thomas CALONGE -- Année 2020
@#$#@#$#@
GRAPHICS-WINDOW
251
10
1030
790
-1
-1
3.0
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
10.0

BUTTON
24
46
126
79
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
23
115
125
148
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
21
151
200
184
infection-chance
infection-chance
0
100
50.0
1
1
%
HORIZONTAL

PLOT
10
239
240
416
Number Sick
time
sick
0.0
10.0
0.0
6.0
true
false
"create-temporary-plot-pen word \"run \" run-number\nset-plot-pen-color item (run-number mod 5)\n                        [blue red green orange violet]" "plot num-sick"
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
24
10
203
43
num-population
num-population
1
10000
10000.0
1
1
NIL
HORIZONTAL

MONITOR
80
191
170
236
Number Sick
num-sick
0
1
11

BUTTON
24
80
126
113
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
138
92
235
110
keeps old plots
11
0.0
0

TEXTBOX
138
57
235
75
clears old plots\n
11
0.0
0

SLIDER
47
449
196
482
step-size
step-size
1
5
1.0
1
1
NIL
HORIZONTAL

BUTTON
127
114
229
147
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
1104
42
1276
75
max-hopital
max-hopital
10
1000
10.0
10
1
NIL
HORIZONTAL

PLOT
1064
103
1317
302
Place en réanimation
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
"default" 1.0 0 -16777216 true "" "plot nb-place-disponible"

PLOT
1065
507
1319
694
Nombre de mort
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
"default" 1.0 0 -16777216 true "" "plot deaths"

PLOT
1065
305
1321
500
Gens ayant besoin d'une réanimation
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
"default" 1.0 0 -16777216 true "" "plot count turtles with [ grave? ]"
"pen-1" 1.0 0 -5298144 true "" "plot max-hopital + nb-lit-croissant"

MONITOR
62
497
180
542
Number Incubating
count turtles with [ incubation? ]
17
1
11

SWITCH
65
754
189
787
confinement
confinement
0
1
-1000

PLOT
12
548
236
724
Number Incubating
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
"default" 1.0 0 -16777216 true "" "plot count turtles with [ incubation? ]"

SLIDER
18
800
346
833
%population-needed-to-start
%population-needed-to-start
0
10
0.5
0.001
1
NIL
HORIZONTAL

SLIDER
366
801
538
834
j-deconfinement
j-deconfinement
1
120
50.0
1
1
NIL
HORIZONTAL

SLIDER
559
803
731
836
taux-desobeissance
taux-desobeissance
0
100
30.0
1
1
NIL
HORIZONTAL

MONITOR
747
797
834
842
NIL
confinement?
17
1
11

MONITOR
1082
714
1305
759
Population non-confiner
count turtles with [ confiner? = false ]
17
1
11

SLIDER
556
841
736
874
%population-with-mask
%population-with-mask
0
100
40.0
1
1
NIL
HORIZONTAL

MONITOR
1100
770
1278
815
Population ayant un masque
count turtles with [ masque? ]
17
1
11

SLIDER
300
840
542
873
%population-deconfined-per-week
%population-deconfined-per-week
1
100
25.0
1
1
NIL
HORIZONTAL

MONITOR
848
796
1014
841
Jours depuis le confinement
int (delay-deconfinement / 12)
17
1
11

SLIDER
119
839
291
872
%impact-of-mask
%impact-of-mask
0
100
93.0
1
1
NIL
HORIZONTAL

MONITOR
1098
823
1282
868
Gens étant dans un état grave
count turtles with [ grave? ]
17
1
11

SLIDER
797
844
969
877
%detected
%detected
0
100
100.0
1
1
NIL
HORIZONTAL

SWITCH
1488
43
1617
76
stop-and-go?
stop-and-go?
0
1
-1000

MONITOR
1419
90
1680
135
Population nécessaire pour débuter le confinement
num-population * ( %population-needed-to-start / 100)
17
1
11

SLIDER
1469
145
1641
178
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
1471
217
1643
250
%croissance-mask
%croissance-mask
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
1471
257
1690
290
%decroissance-desobeissance
%decroissance-desobeissance
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
1471
294
1674
327
%croissance-lit-reanimation
%croissance-lit-reanimation
0
100
10.0
1
1
NIL
HORIZONTAL

MONITOR
1301
793
1373
838
Gens rebel
count turtles with [ rebel? ]
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

Healthy "agents" on the same patch as sick agents have an INFECTION-CHANCE chance of becoming ill.

## HOW TO USE IT

### Buttons

SETUP/CLEAR - sets up the world and clears plots.
SETUP/KEEP - sets up the world without clearing the plot; this lets you compare results from different runs.
GO - runs the simulation.
INFECT - infects one of the androids

### Sliders

NUM-ANDROIDS - determines how many androids are created at setup
INFECTION-CHANCE - a healthy agent's chance at every time step to become sick if it is on the same patch as an infected agent

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
