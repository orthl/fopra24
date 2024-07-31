; notes: jede Turtle hat 4 ausgehende Links (basierend auf der Nummer der connecteten Nachbarn) und eine zufällige Zahl an Turtles, die ihr folgen
;        Influencer Turtles haben dabei mehr follower als nicht-influencer
; num-nodes : Gesamtanzahl der Nodes
; rewiring-probability: spiegelt p in einem Small Network wider (Wahrscheinlichkeit, dass ein bestehender Link neu mit einem zuf. Node verlinkt wird)
; num-connected-neighbors: Anzahl an Nachbarn, mit denen der Node initial verbunden wird (entspricht der Anzahl an ausgehenden Links pro Node)
; influencer-percentage: prozentueller Anteil der Influencer im Netzwerk
; influencer-link-probability: Wahrscheinlichkeit dafür, dass ein Link in der Rewire-Phase zu einem Influencer statt einem "normalen" Node gezogen wird
;

;----- Github Befehle -----
;cd /P/Uni/Forschungspraktikum/NetLogo
;git status
;git add .
;git commit -m "Message"
;git push
;-------
;cd /P/Uni/Forschungspraktikum/NetLogo
;git status
;git fetch
;git pull

extensions [array table]

globals [
  all-influencer ; list of all influencer
  all-nodes ; list of all nodes
]

turtles-own [
  influencer?              ; is agent influencer?

  attitude
  initial-attitude
  credibility

  social-norm
  initial-norm

  perceived-behavioral-control ; Composite perceived behavioral control (self-efficacy + conditions) - Weighting: 50/50
  self-efficacy
  conditions

  intent
]

breed [posts post]
posts-own [
  likes
  comment-average
  reposts
  origin-agent-id
  intention
  post-credibility
  relevance
]

all-posts-own [
  link-credibility  ; composite if credibility of influencer and reposting agent and the post-summary (#likes, #comments, ..)
]


directed-link-breed [all-followed followed] ; directed links to distinguish between follower and following agent
directed-link-breed [all-posts posted]  ; directed links to distinguish between posting and receiving agent

; -----------------------------------------------------------------------------------------
; ------------------------------- Setup ---------------------------------------------------
; -----------------------------------------------------------------------------------------

to setup
  clear-all
  reset-ticks

  ; Create network
  create-nodes
  wire-lattice
  rewire
  layout

  ; initialize nodes
  initialize-nodes

  ask links [ set color gray ]
  print-turtle-link-counts
  print-influencer-count
  print-initial-attitudes

end

to go
  print (word "go")
  tick
end

to test
  clear-all
  let array [
    [1 2 3]
    [4 5 6]
    [7 8 9]
  ]  ;; Beispiel: Ein 3x3 "Array" mit vorgegebenen Werten

  print item 0 (item 1 array)

end


; -----------------------------------------------------------------------------------------
; ------------------------- Initialization of Agents --------------------------------------
; -----------------------------------------------------------------------------------------

to initialize-nodes
  initialize-initial-attitudes
  ask turtles [
    set credibility random-float 1                           ; Determine credibility of external influences randomly
    set attitude initial-attitude

    set initial-norm 0                                       ; Determine initial norm randomly
    set social-norm initial-norm                             ; no immediate env yet, so initial norm

    set self-efficacy random-float 1                         ; Determine self-efficacy randomly
    set conditions random-float 1                            ; Determine conditions randomly
    set perceived-behavioral-control (self-efficacy + conditions) / 2 ; Calculate composite perceived behavioral control

    ; TODO: Gewichtung recherchieren
    set intent 0
    set intent (attitude + social-norm + perceived-behavioral-control) / 3 ; Calculate composite intention
  ]
end

to initialize-initial-attitudes

  let id-groups table:make
  table:put id-groups 0.135 0.8
  table:put id-groups 0.34 0.6
  table:put id-groups 0.3399 0.4  ; has to be a bit different than the first 0.34, otherwise it would overwrite it
  table:put id-groups 0.16 0.2

  let groupKeys table:keys id-groups
  foreach groupKeys [
  group ->
    let value table:get id-groups group
    let all-nodes-agentset turtle-set all-nodes
    let tmp (group * num-nodes)
    set tmp round tmp
    ask n-of tmp all-nodes-agentset [
      set initial-attitude value
      set all-nodes remove self all-nodes
    ]
  ]
end


; -----------------------------------------------------------------------------------------
; ------------------------------- network -------------------------------------------------
; -----------------------------------------------------------------------------------------

; ------------------ create nodes ---------------
to create-nodes
  ; create nodes, arrange them in a circle
  set-default-shape turtles "circle"
  set all-influencer []
  set all-nodes []
  create-turtles num-nodes [
    set color gray + 2
    set all-nodes fput self all-nodes
  ]
  layout-circle (sort turtles) max-pxcor - 1

  ; pick x influencers and put them into global list
  ask n-of (influencer-percentage * num-nodes) turtles [
    set influencer? true
    set all-influencer fput self all-influencer
    set all-nodes remove self all-nodes
    set color blue
    set initial-attitude 1
  ]
end

; ------------------ create lattice ---------------
to wire-lattice
  ; iterate over nodes
  let n 0
  while [ n < count turtles ] [
    ; make edges with the next x neighbors
    let cnt 1
    ;repeat num_connected_neighbors [
    repeat random-num-connected-neighbors [
      make-edge turtle n
     turtle ((n + cnt) mod count turtles)
     "curve" ; alternatively "default"
      set cnt cnt + 1
    ]
    set n n + 1
  ]
end

to-report random-num-connected-neighbors
  let lower-limit num-connected-neighbors / 2
  let upper-limit num-connected-neighbors + lower-limit
  report round (random-float lower-limit + random-float upper-limit)
end

; ------------------ rewire links ------------------
to rewire
  ask links [
    ; test, if link should be rewired
    if (random-float 1) < rewiring-probability [
      ; node-A remains the same
      let node-A end1

      ; probalbility that the node should be rewired to an influencer or not
      ifelse (random-float 1) > influencer-link-prob [
        ; if the link should not be rewired to an influencer,
        ; find a node distinct from A, which has no link to A and is no influencer, link those two nodes an delete the old one
        let node-B one-of turtles with [ (self != node-A) and (not link-neighbor? node-A) and not(member? self all-influencer) ]
        ask node-A [ create-followed-to node-B ]
        die
       ][
        ; if the link should be rewired to an influencer, take a random one out of the list, link the nodes and delete old link
        ; for the one-of condition, the list of influencer should be an agentset
        let all-influencer-set turtle-set all-influencer
        let random-influencer one-of all-influencer-set with [(self != node-A) and (not link-neighbor? node-A)]

        ; check if there is an influencer left, that this node can follow

        ifelse random-influencer != nobody [
          ; if there is an influencer left, rewire with a random one
          ask node-A [ create-followed-to random-influencer ]
          die
        ][
          ; if there is no influencer left, rewire with a random node
          let node-B one-of turtles with [ (self != node-A) and (not link-neighbor? node-A) and not(member? self all-influencer) ]
          ask node-A [ create-followed-to node-B ]
          die
        ]
      ]
     ]
   ]
end


; ----------- make edge from node A to node B ---------
to make-edge [ node-A node-B the-shape]
   ask node-A [
    create-followed-to node-B [
      set shape the-shape
    ]
  ]
end

;----------------- rearrange network -----------

to layout
  repeat 10 [ layout-spring turtles links 0.2 5 1]
end




; -------------- report -----------------------------------------------------------------

to print-turtle-link-counts
  let cnt 0
  let cnt-2 0
  let all-followers []
  ask turtles [
    let num-links count my-in-links  ; links to all nodes that follow this node
    let num-links-2 count my-out-links ; links to nodes this one follows
    set cnt cnt + num-links
    set cnt-2 cnt-2 + num-links-2
    set all-followers fput num-links all-followers
    ;print (word "Turtle " who " has " num-links " in links and " num-links-2 " out links")
  ]
  print(word "count in-links  " cnt)
  print(word "count out-links " cnt-2)
  print(word "count links     " count links)
  set all-followers sort all-followers
  print all-followers
end

to print-influencer-count
  let cnt 0
  let all-followers []
  ask turtles [
    if influencer? = true [
          set cnt cnt + 1
          let num-links count my-in-links
          set all-followers fput num-links all-followers
       ]
  ]
  print (word "Number of influencers " cnt)
  set all-followers sort all-followers
  print all-followers
end

to print-initial-attitudes

  let count-0.2 count turtles with [initial-attitude = 0.2]
  let count-0.4 count turtles with [initial-attitude = 0.4]
  let count-0.6 count turtles with [initial-attitude = 0.6]
  let count-0.8 count turtles with [initial-attitude = 0.8]
  let count-1.0 count turtles with [initial-attitude = 1.0]

  ; Ausgabe der Ergebnisse
  print (word "Anzahl Turtles mit initial-attitude = 0.2: " count-0.2)
  print (word "Anzahl Turtles mit initial-attitude = 0.4: " count-0.4)
  print (word "Anzahl Turtles mit initial-attitude = 0.6: " count-0.6)
  print (word "Anzahl Turtles mit initial-attitude = 0.8: " count-0.8)
  print (word "Anzahl Turtles mit initial-attitude = 1.0: " count-1.0)
  print(word "übrige Agents "  length all-nodes)
end


; Copyright 2015 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
330
10
830
511
-1
-1
12.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

SLIDER
10
120
165
153
num-nodes
num-nodes
50
2000
400.0
50
1
NIL
HORIZONTAL

SLIDER
10
160
165
193
rewiring-probability
rewiring-probability
0
1
0.75
0.01
1
NIL
HORIZONTAL

BUTTON
5
10
110
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

SLIDER
10
200
165
233
num-connected-neighbors
num-connected-neighbors
1
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
10
240
165
273
influencer-percentage
influencer-percentage
0
0.3
0.025
0.005
1
NIL
HORIZONTAL

SLIDER
10
280
165
313
influencer-link-prob
influencer-link-prob
0
1
0.25
0.05
1
NIL
HORIZONTAL

TEXTBOX
15
95
165
113
Networkvariables
11
0.0
1

BUTTON
135
10
198
43
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
1

BUTTON
15
50
78
83
NIL
test
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This model explores the formation of networks that result in the "small world" phenomenon -- the idea that a person is only a couple of connections away from any other person in the world.

A popular example of the small world phenomenon is the network formed by actors appearing in the same movie (e.g., "[Six Degrees of Kevin Bacon](https://en.wikipedia.org/wiki/Six_Degrees_of_Kevin_Bacon)"), but small worlds are not limited to people-only networks. Other examples range from power grids to the neural networks of worms. This model illustrates some general, theoretical conditions under which small world networks between people or things might occur.

## HOW IT WORKS

This model is an adaptation of the [Watts-Strogatz model](https://en.wikipedia.org/wiki/Watts-Strogatz_model) proposed by Duncan Watts and Steve Strogatz (1998). It begins with a network where each person (or "node") is connected to his or her two neighbors on either side. Using this a base, we then modify the network by rewiring nodes–changing one end of a connected pair of nodes and keeping the other end the same. Over time, we analyze the effect this rewiring has the on various connections between nodes and on the properties of the network.

Particularly, we're interested in identifying "small worlds." To identify small worlds, the "average path length" (abbreviated "apl") and "clustering coefficient" (abbreviated "cc") of the network are calculated and plotted after a rewiring is performed. Networks with _short_ average path lengths and _high_ clustering coefficients are considered small world networks. See the **Statistics** section of HOW TO USE IT on how these are calculated.

## HOW TO USE IT

The NUM-NODES slider controls the size of the network. Choose a size and press SETUP.

Pressing the REWIRE-ONE button picks one edge at random, rewires it, and then plots the resulting network properties in the "Network Properties Rewire-One" graph. The REWIRE-ONE button _ignores_ the REWIRING-PROBABILITY slider. It will always rewire one exactly one edge in the network that has not yet been rewired _unless_ all edges in the network have already been rewired.

Pressing the REWIRE-ALL button starts with a new lattice (just like pressing SETUP) and then rewires all of the edges edges according to the current REWIRING-PROBABILITY. In other words, it `asks` each `edge` to roll a die that will determine whether or not it is rewired. The resulting network properties are then plotted on the "Network Properties Rewire-All" graph. Changing the REWIRING-PROBABILITY slider changes the fraction of edges rewired during each run. Running REWIRE-ALL at multiple probabilities produces a range of possible networks with varying average path lengths and clustering coefficients.

When you press HIGHLIGHT and then point to a node in the view it color-codes the nodes and edges. The node itself turns white. Its neighbors and the edges connecting the node to those neighbors turn orange. Edges connecting the neighbors of the node to each other turn yellow. The amount of yellow between neighbors gives you a sort of indication of the clustering coefficient for that node. The NODE-PROPERTIES monitor displays the average path length and clustering coefficient of the highlighted node only. The AVERAGE-PATH-LENGTH and CLUSTERING-COEFFICIENT monitors display the values for the entire network.

### Statistics

**Average Path Length**: Average path length is calculated by finding the shortest path between all pairs of nodes, adding them up, and then dividing by the total number of pairs. This shows us, on average, the number of steps it takes to get from one node in the network to another.

In order to find the shortest paths between all pairs of nodes we use the [standard dynamic programming algorithm by Floyd Warshall] (https://en.wikipedia.org/wiki/Floyd-Warshall_algorithm). You may have noticed that the model runs slowly for large number of nodes. That is because the time it takes for the Floyd Warshall algorithm (or other "all-pairs-shortest-path" algorithm) to run grows polynomially with the number of nodes.

**Clustering Coefficient**: The clustering coefficient of a _node_ is the ratio of existing edges connecting a node's neighbors to each other to the maximum possible number of such edges. It is, in essence, a measure of the "all-my-friends-know-each-other" property. The clustering coefficient for the entire network is the average of the clustering coefficients of all the nodes.

### Plots

1. The "Network Properties Rewire-One" visualizes the average-path-length and clustering-coefficient of the network as the user increases the number of single-rewires in the network.

2. The "Network Properties Rewire-All" visualizes the average-path-length and clustering coefficient of the network as the user manipulates the REWIRING-PROBABILITY slider.

These two plots are separated because the x-axis is slightly different.  The REWIRE-ONE x-axis is the fraction of edges rewired so far, whereas the REWIRE-ALL x-axis is the probability of rewiring.

The plots for both the clustering coefficient and average path length are normalized by dividing by the values of the initial lattice. The monitors CLUSTERING-COEFFICIENT and AVERAGE-PATH-LENGTH give the actual values.

## THINGS TO NOTICE

Note that for certain ranges of the fraction of nodes rewired, the average path length decreases faster than the clustering coefficient. In fact, there is a range of values for which the average path length is much smaller than clustering coefficient. (Note that the values for average path length and clustering coefficient have been normalized, so that they are more directly comparable.) Networks in that range are considered small worlds.

## THINGS TO TRY

Can you get a small world by repeatedly pressing REWIRE-ONE?

Try plotting the values for different rewiring probabilities and observe the trends of the values for average path length and clustering coefficient.  What is the relationship between rewiring probability and fraction of nodes? In other words, what is the relationship between the rewire-one plot and the rewire-all plot?

Do the trends depend on the number of nodes in the network?

Set NUM-NODES to 80 and then press SETUP. Go to BehaviorSpace and run the VARY-REWIRING-PROBABILITY experiment. Try running the experiment multiple times without clearing the plot (i.e., do not run SETUP again).  What range of rewiring probabilities result in small world networks?

## EXTENDING THE MODEL

Try to see if you can produce the same results if you start with a different type of initial network. Create new BehaviorSpace experiments to compare results.

In a precursor to this model, Watts and Strogatz created an "alpha" model where the rewiring was not based on a global rewiring probability. Instead, the probability that a node got connected to another node depended on how many mutual connections the two nodes had. The extent to which mutual connections mattered was determined by the parameter "alpha." Create the "alpha" model and see if it also can result in small world formation.

## NETLOGO FEATURES

Links are used extensively in this model to model the edges of the network. The model also uses custom link shapes for neighbor's neighbor links.

Lists are used heavily in the procedures that calculates shortest paths.

## RELATED MODELS

See other models in the Networks section of the Models Library, such as Giant Component and Preferential Attachment.

Check out the NW Extension General Examples model to see how similar models might implemented using the built-in NW extension.

## CREDITS AND REFERENCES

This model is adapted from: Duncan J. Watts, Six Degrees: The Science of a Connected Age (W.W. Norton & Company, New York, 2003), pages 83-100.

The work described here was originally published in: DJ Watts and SH Strogatz. Collective dynamics of 'small-world' networks, Nature, 393:440-442 (1998).

The small worlds idea was first made popular by Stanley Milgram's famous experiment (1967) which found that two random US citizens where on average connected by six acquaintances (giving rise to the popular "six degrees of separation" expression): Stanley Milgram. The Small World Problem, Psychology Today, 2: 60-67 (1967).

This experiment was popularized into a game called "six degrees of Kevin Bacon" which you can find more information about here: https://oracleofbacon.org

Thanks to Connor Bain for updating this model in 2020.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (2015).  NetLogo Small Worlds model.  http://ccl.northwestern.edu/netlogo/models/SmallWorlds.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2015 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2015 -->
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
setup
repeat 5 [rewire-one]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="vary-rewiring-probability" repetitions="5" runMetricsEveryStep="false">
    <go>rewire-all</go>
    <timeLimit steps="1"/>
    <exitCondition>rewiring-probability &gt; 1</exitCondition>
    <metric>average-path-length</metric>
    <metric>clustering-coefficient</metric>
    <steppedValueSet variable="rewiring-probability" first="0" step="0.025" last="1"/>
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

curve
3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve-a
-3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
