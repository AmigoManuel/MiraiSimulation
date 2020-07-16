;; Por hacer
;; Ordenar el codigo, añadir metricas y documentar

globals[
  vulnerable_devices
  device_list
]

;; Clases para mejor entendimiento
breed [routers router]
breed [devices device]
breed [servers server]

to setup
  clear-all
  reset-ticks
  identify-devices
  setup-servers
  setup-routers
  setup-devices
  setup-infection
end

;; Dispositivos iniciales que cuentan con la infección
to setup-infection
  ask n-of initial_devices_infected devices [
    ask self [
      set label "vulnerable"
    ]
    set color red
  ]
  ask n-of initial_routers_infected routers [
    ask self [
      set label "vulnerable"
    ]
    set color red
  ]
end

;; Identifica los dispositivos potencialmente vulnerables
;; Según el tipo de ataque
to identify-devices
  ;;Lista de dispositivos IoT disponibles
  set device_list ["tv" "speaker" "printer" "consola" "phone" "lavadora" "fridge" "notebook" "camera" "dvr"]
  ;;Configuraciones de dispositivos vulnerables
  if infection_type = "all"[
    set vulnerable_devices device_list
  ]
  if infection_type = "mirai infection"[
    set vulnerable_devices ["router" "camera" "dvr"]
  ]
  if infection_type = "all IoT devices"[
    set vulnerable_devices ["tv" "speaker" "router" "printer" "lavadora" "fridge" "camera"]
  ]
end

to setup-servers
  create-servers 3
  ask servers[
    set size 2
    set color gray
    set shape "computer workstation"
    setxy -100 100
  ]
  ask server 0[
    set label "CnC"
  ]
  ask server 1[
    set label "report"
    set xcor 108
  ]
  ask server 2[
    set label "loader"
    set xcor 111
  ]
end

;; Inicializa los routers
to setup-routers
  create-routers n_routers
  ask routers[
    let me self

    set size 1
    set shape "router"
    set color gray

    setxy -15 + random 30 -15 + random 30

    ;; Marca el dispositivo como seguro
    set label "seguro"
    ;; Según su probabilidad de vulnerabilidad
    ;; determina si es vulnerable o no
    if random-float 1 < prob_vulnerability[
      set label "vulnerable"
    ]

    ;; Conexión con otros routers
    ;; La cantidad de conexiones que tenga
    ;; la lee desde el slider
    repeat 1 + random max_router_connection[
      let other_router one-of routers
      while[other_router = me][
        set other_router one-of routers
      ]
      create-link-with other_router
      ]
    ]
end

;; Inicializa los dispositivos
;; Estos se asocian a un router
to setup-devices
  create-devices n_devices
  ask devices[
    set size 1
    set color gray
    set shape random-shape

    let local_router one-of routers

    ;; Posciciona los dispositivos
    let pos_x [xcor] of local_router
    let pos_y [ycor] of local_router
    let r 3
    let angle random 360
    setxy pos_x + r * sin angle pos_y + r * cos angle
    create-link-with local_router

    ;; Marca el dispositivo como seguro
    set label "seguro"
    ;; Si es un dispositivo potencialmente vulnerable
    if member? shape vulnerable_devices[
      ;; Según su probabilidad de vulnerabilidad
      ;; determina si es vulnerable o no
      if random-float 1 < prob_vulnerability[
        set label "vulnerable"
      ]
    ]
  ]
end


to-report random-shape
  report one-of device_list
end

to go
  ;; Procedimientos de conexión en la red
  connection-procedure
  ;; Obtiene los reportes de vulnerables
  let reports check-reports
  ;; Carga infección en vulnerables
  load-worm reports
  tick
end

to load-worm [ reports ]
  foreach reports [
    [victim] ->
    ask server 2 [
      create-link-with victim [
        set color yellow
        if not show_loader_links? [hide-link]
        ask other-end [
          set color red
        ]
      ]
    ]
  ]
end

to-report check-reports
  ;; Lista con dispositivos reportados
  let reports []
  ask server 1 [
    ;; Pregunta si tiene links
    if any? my-links[
      ;; Le dice a sus links
      ask my-links [
        ;; Que se guarden en reports los vulnerables
        set reports lput other-end reports
      ]
    ]
  ]
  report reports
end

to connection-procedure
  ask devices [
    let src one-of devices
    let moneda random 3
    if moneda = 0 [
      connection src
    ]
    if moneda = 1 [
      disconnection src
    ]
  ]
  ask routers [
    let src one-of routers
    let moneda random 3
    if moneda = 0 [
      connection src
    ]
    if moneda = 1 [
      disconnection src
    ]
  ]
end

to connection[src]
  ;; Si no esta infectado sigue este proceso
  if [color] of src != red [
    ask src[
      let lik one-of my-links
      ask lik [
        if [color] of other-end != red [
          if other-end != server 1 and other-end != server 2 [
            set color green
            connection-recurse src connection_len "seguro"
          ]
        ]
      ]
      set color green
    ]
  ]
  ;; Si esta infectado sigue este proceso
  if [color] of src = red [
    ask src[
      let lik one-of my-links
      ask lik [
        ;; Identifica un link de ataque en rojo
        if other-end != server 1 and other-end != server 2 [
          set color red
          connection-recurse other-end connection_len "vulnerable"
        ]
      ]
    ]
  ]
end

to connection-recurse[src recurse tag]
  set recurse recurse - 1
  if recurse > 0 [
    if tag = "seguro" [
      ask src [
        let lik one-of my-links
        ask lik [
          if [color] of other-end != red [
            if other-end != server 1 and other-end != server 2 [
              set color green
              connection-recurse other-end recurse tag
            ]
          ]
        ]
      ]
    ]
    if tag = "vulnerable" [
      ask src [
        let lik one-of my-links
        ask lik [
          if [color] of other-end != red [
            if other-end != server 1 and other-end != server 2 [
              set color red
              connection-recurse src recurse tag
            ]
          ]
        ]
      ]
    ]
  ]
  if recurse = 0 [
    if tag = "vulnerable"[
    if [label] of other-end = "vulnerable" [
      ;; Crea un enlace con el servidor de reporte
      ask other-end [
        create-link-with server 1 [
          set color yellow
          if not show_report_links? [hide-link]
        ]
      ]
    ]
    ]
  ]
end

to disconnection[src]
  ask src[
    let lik one-of my-links
    ask lik[
      if other-end != server 1 and other-end != server 2 [
        if [color] of other-end != red [
          set color gray
        ]
      ]
    ]
    if color != red [
      set color gray
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
11
10
748
748
-1
-1
17.8
1
10
1
1
1
0
1
1
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
757
10
820
43
setup
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
825
10
930
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
758
49
930
82
n_routers
n_routers
10
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
759
94
931
127
n_devices
n_devices
100
1000
100.0
1
1
NIL
HORIZONTAL

CHOOSER
758
140
934
185
infection_type
infection_type
"mirai infection" "all IoT devices" "all"
1

SLIDER
758
197
935
230
prob_vulnerability
prob_vulnerability
0
1
0.53
0.01
1
NIL
HORIZONTAL

SLIDER
760
241
935
274
max_router_connection
max_router_connection
1
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
762
283
934
316
initial_devices_infected
initial_devices_infected
0
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
760
326
937
359
initial_routers_infected
initial_routers_infected
0
20
0.0
1
1
NIL
HORIZONTAL

SLIDER
759
365
939
398
connection_len
connection_len
1
3
2.0
1
1
NIL
HORIZONTAL

BUTTON
971
50
1034
83
NIL
go
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
974
19
1124
37
Debug
11
0.0
1

SWITCH
971
94
1140
127
show_report_links?
show_report_links?
0
1
-1000

SWITCH
972
138
1141
171
show_loader_links?
show_loader_links?
0
1
-1000

PLOT
763
408
1188
748
Devices/Routers status
ticks
devices and routers
0.0
300.0
0.0
300.0
true
true
"" ""
PENS
"not connected" 1.0 0 -7500403 true "" "plot count turtles with [color = gray]"
"not infected" 1.0 0 -13840069 true "" "plot count turtles with [color = green]"
"infected" 1.0 0 -2674135 true "" "plot count turtles with [color = red]"

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

camera
false
0
Rectangle -7500403 true true 180 210 240 225
Rectangle -7500403 true true 240 180 255 255
Polygon -7500403 true true 165 165 150 180 180 225 195 210 165 165
Polygon -7500403 true true 90 225 225 90 210 75 105 180 60 180 90 225
Polygon -7500403 true true 45 165 105 165 195 75 210 60 180 30 45 165
Polygon -7500403 true true 45 180 75 225 60 240 30 195 45 180

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

computer workstation
false
0
Rectangle -7500403 true true 60 45 240 180
Polygon -7500403 true true 90 180 105 195 135 195 135 210 165 210 165 195 195 195 210 180
Rectangle -16777216 true false 75 60 225 165
Rectangle -7500403 true true 45 210 255 255
Rectangle -10899396 true false 249 223 237 217
Line -16777216 false 60 225 120 225

consola
false
0
Circle -7500403 true true 15 105 120
Circle -7500403 true true 165 105 120
Rectangle -7500403 true true 75 105 225 180
Circle -1 true false 180 150 30
Circle -1 true false 210 180 30
Circle -1 true false 240 150 30
Circle -1 true false 210 120 30
Rectangle -1 true false 105 120 135 135
Rectangle -1 true false 150 120 180 135
Polygon -1 true false 75 60
Polygon -1 true false 60 135 60 150 45 165 30 165 30 180 45 180 60 195 60 210 75 210 75 195 90 180 105 180 105 165 90 165 75 150 75 135 60 135
Polygon -1 true false 120 90

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

dvr
false
0
Rectangle -7500403 true true 15 165 285 225
Polygon -7500403 true true 15 165 45 120 255 120 285 165 15 165
Line -16777216 false 15 165 285 165
Polygon -1 true false 225 180 210 195 225 210 225 180
Polygon -1 true false 255 180 255 210 270 195 255 180
Polygon -1 true false 225 180 240 165 255 180 225 180
Polygon -1 true false 225 210 240 225 255 210 225 210
Circle -1 true false 225 180 30
Rectangle -1 true false 165 180 195 195
Rectangle -1 true false 120 180 150 195
Rectangle -1 true false 75 180 105 195

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

fridge
false
0
Circle -1 true false 75 30 30
Rectangle -1 true false 75 45 225 240
Circle -1 true false 195 30 30
Circle -1 true false 75 225 30
Circle -1 true false 195 225 30
Rectangle -1 true false 90 30 210 45
Rectangle -1 true false 90 240 210 255
Circle -7500403 false true 75 30 30
Circle -7500403 false true 195 30 30
Circle -7500403 false true 195 225 30
Circle -7500403 false true 75 225 30
Rectangle -1 true false 210 45 225 240
Rectangle -1 true false 90 30 210 60
Rectangle -1 true false 90 225 210 255
Rectangle -1 true false 75 45 90 240
Line -7500403 true 75 45 75 240
Line -7500403 true 225 45 225 240
Line -7500403 true 90 30 210 30
Line -7500403 true 90 255 210 255
Line -7500403 true 75 105 225 105
Rectangle -7500403 false true 90 45 105 90
Rectangle -7500403 false true 90 120 105 195
Rectangle -7500403 true true 90 255 120 270
Rectangle -7500403 true true 180 255 210 270

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

lavadora
false
0
Rectangle -7500403 true true 60 75 240 255
Circle -1 true false 86 116 127
Rectangle -7500403 true true 60 45 240 75
Circle -7500403 true true 60 30 30
Circle -7500403 true true 210 30 30
Rectangle -7500403 true true 75 30 225 45
Line -1 false 60 90 240 90
Circle -1 true false 150 45 30
Circle -1 true false 195 45 30

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

notebook
false
0
Rectangle -7500403 true true 45 45 60 180
Rectangle -7500403 true true 60 45 255 60
Rectangle -7500403 true true 240 60 255 180
Rectangle -7500403 true true 60 165 240 180
Polygon -7500403 true true 45 195 30 240 270 240 255 195 45 195

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

phone
false
0
Circle -7500403 true true 180 30 30
Circle -7500403 true true 90 210 30
Circle -7500403 true true 180 210 30
Rectangle -7500403 true true 105 30 195 60
Rectangle -7500403 true true 105 210 195 240
Rectangle -7500403 true true 90 45 210 225
Circle -7500403 true true 90 30 30
Circle -1 true false 135 195 30
Rectangle -1 true false 105 45 195 180

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

printer
false
0
Circle -7500403 true true 210 135 60
Circle -7500403 true true 30 135 58
Rectangle -7500403 true true 30 165 270 240
Rectangle -7500403 true true 60 135 240 165
Rectangle -1 true false 105 195 195 270
Rectangle -1 true false 105 75 195 135
Line -16777216 false 120 210 165 210
Line -16777216 false 120 225 165 225
Line -16777216 false 120 240 180 240
Line -16777216 false 120 255 165 255
Rectangle -16777216 true false 195 150 240 165

router
false
15
Circle -7500403 true false 195 135 90
Circle -7500403 true false 15 135 90
Rectangle -7500403 true false 60 135 240 225
Circle -1 true true 30 150 60
Circle -7500403 true false 45 165 30
Rectangle -7500403 true false 105 90 135 135
Circle -7500403 true false 99 54 42
Circle -1 true true 105 165 30
Circle -1 true true 240 165 30
Line -16777216 false 120 195 255 195
Circle -16777216 false false 105 165 30
Circle -16777216 false false 240 165 30
Rectangle -1 true true 120 165 255 195
Line -16777216 false 120 165 255 165

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

speaker
false
0
Rectangle -7500403 true true 75 45 225 255
Rectangle -7500403 true true 90 240 210 270
Circle -1 true false 90 135 120
Circle -1 true false 120 60 60
Circle -7500403 true true 103 148 95
Circle -1 true false 116 161 67
Circle -7500403 true true 135 75 30
Circle -7500403 true true 75 30 30
Circle -7500403 true true 195 30 30
Circle -7500403 true true 75 240 30
Circle -7500403 true true 195 240 30
Rectangle -7500403 true true 90 30 210 60

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

tv
false
0
Rectangle -7500403 true true 30 60 270 210
Polygon -7500403 true true 225 240 195 210 225 210 255 240 225 240
Polygon -7500403 true true 75 210 45 240 75 240 105 210 75 210
Rectangle -1 true false 45 75 255 195

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

connection-link
0.0
-0.2 0 0.0 1.0
0.0 1 4.0 4.0 2.0 2.0
0.2 0 0.0 1.0
link direction
true
0
Polygon -7500403 true true 90 180 150 90 210 180 165 180 150 165 135 180 90 180
@#$#@#$#@
0
@#$#@#$#@
