extensions [array table]

globals [
  all-influencer ; list of all influencer
  all-nodes ; list of all nodes
]

turtles-own [
  influencer?              ; is agent influencer?

  attitude
  initial-attitude
  comfort
  env-awareness

  credibility

  social-norm
  initial-norm

  perceived-behavioral-control
  self-efficacy
  conditions

  intent
]

breed [posts post]
posts-own [
  likes
  comment-average
  comments
  reposts
  origin-agent-id
  intention
  interactions
  impressions
  engagement-rate
]


directed-link-breed [all-followed followed] ; directed links to distinguish between follower and following agent
directed-link-breed [all-posts posted]  ; directed links to distinguish between posting and receiving agent

; -----------------------------------------------------------------------------------------
; ------------------------------- Setup ---------------------------------------------------
; -----------------------------------------------------------------------------------------

to setup
  clear-all
  reset-ticks

  if use-random-seed? [random-seed seed]

  ; Create network
  create-nodes
  wire-lattice
  rewire
  layout

  ; initialize nodes
  initialize-nodes

  ; print information about infomration of setup
  ;print all-influencer
  ;print-adoption-rates
  ;print-influencer-count
  ;print-turtle-link-counts
  ;print-initial-attitudes

end

to go
  ask posts [die]
  ask links [hide-link]

  ; Distribute posts
  let-influencer-post

  ask posts [
    ifelse impressions != 0
      [set engagement-rate (interactions / impressions)]
      [set engagement-rate 0]
  ]

  tick
end

; -----------------------------------------------------------------------------------------
; ------------------------- Initialization of Agents --------------------------------------
; -----------------------------------------------------------------------------------------

to initialize-nodes
  initialize-initial-attitudes
  ask turtles [
    set credibility random-float 1                           ; determine credibility of agent

    set attitude initial-attitude

    set initial-norm random-float 1                          ; determine initial norm randomly
    set social-norm initial-norm                             ; no immediate env yet, so initial norm

    set self-efficacy random-float 1                         ; determine self-efficacy randomly
    set conditions random-float 1                            ; determine conditions randomly
    set perceived-behavioral-control (self-efficacy + conditions) / 2 ; Calculate composite perceived behavioral control

    ; if agent is influencer, overwrite all values with one
    if influencer? = true [
      set env-awareness 1
      set comfort 1
      set attitude 1
      set perceived-behavioral-control 1
      set self-efficacy 1
      set conditions 1
      set social-norm 1
      set initial-norm 1
    ]

    ; calculate intention
    set intent (0.5 * attitude + 0.5 * perceived-behavioral-control) * (1 - 0.3) + 0.3 * social-norm ; Calculate composite intention

  ]
end

to initialize-initial-attitudes

  ; groups of innovation diffusion and their assigned initial attitude
  let id-groups table:make
  table:put id-groups 0.135 0.8
  table:put id-groups 0.34 0.6
  table:put id-groups 0.3399 0.4  ; has to be a bit different than the first 0.34, otherwise it would overwrite it
  table:put id-groups 0.16 0.2

  ; classification of the agents into groups and setting of initial attitude values depending on the group
  let groupKeys table:keys id-groups
  foreach groupKeys [
  group ->
    let value table:get id-groups group
    let all-nodes-agentset turtle-set all-nodes
    let tmp (group * num-nodes)
    set tmp round tmp
    ask n-of tmp all-nodes-agentset [
      set initial-attitude value                      ; determine the initial attitude of agent
      set comfort value                               ; determine comfort of agent
      set env-awareness value                         ; determine the environmental awareness of agent
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
  let influencer-percentage 0.025
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
    repeat random-num-connected-neighbors [
      make-edge turtle n
     turtle ((n + cnt) mod count turtles)
     "curve" ; alternatively "default"
      set cnt cnt + 1
    ]
    set n n + 1
  ]
end

; -------- report random amount of neighbors  ---------
to-report random-num-connected-neighbors
  let num-connected-neighbors ceiling ((ln num-nodes) / 2)
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
      ifelse (random-float 1) <= 0.75 [

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


; -----------------------------------------------------------------------------------------
; ------------------------------- post distribution ---------------------------------------
; -----------------------------------------------------------------------------------------

; ------------ posting of influencer ------------
to let-influencer-post
  let mega-influencers []
  let macro-influencers []
  let micro-influencers []
  let regular-influencers []
  let influencer-list []

  ; extract influencers with follower count
  ask turtles [
    if influencer? = true [
      let num-links count my-in-links  ; links to all nodes that follow this node
      set influencer-list lput (list who num-links) influencer-list
    ]
  ]


  ; sort list based on in links and get min, max and differnence of follower counts
  set influencer-list sort-by [[a b] -> item 1 a < item 1 b] influencer-list
  let min-follower item 1 first influencer-list
  let max-follower item 1 last influencer-list
  let diff-follower max-follower - min-follower

  ; group influencer based on follower count
  foreach influencer-list [
    [influencer] ->
    let follower-count item 1 influencer

    if follower-count <= (min-follower + diff-follower * 0.7) [
      set regular-influencers lput influencer regular-influencers
    ]
    if follower-count > (min-follower + diff-follower * 0.7) and follower-count <= (min-follower + diff-follower * 0.85) [
      set micro-influencers lput influencer micro-influencers
    ]
    if follower-count > (min-follower + diff-follower * 0.85) and follower-count <= (min-follower + diff-follower * 0.95) [
      set macro-influencers lput influencer macro-influencers
    ]
    if follower-count > (min-follower + diff-follower * 0.95) [
      set mega-influencers lput influencer mega-influencers
    ]
  ]

  ; print groups
  ;print (word "Influencer List: " influencer-list)
  ;print (word "Mega-Influencers: " mega-influencers)
  ;print (word "Macro-Influencers: " macro-influencers)
  ;print (word "Micro-Influencers: " micro-influencers)
  ;print (word "Regular-Influencers: " regular-influencers)

  ; --------- generate Posts -----------------
  foreach mega-influencers [ turtle-id ->
    let actual-id item 0 turtle-id
    ask turtle actual-id[
      repeat 2 * posts-frequency[
        create-post self intent credibility
      ]
    ]
  ]

   foreach macro-influencers [ turtle-id ->
    let actual-id item 0 turtle-id
    ask turtle actual-id[
      repeat 1 * posts-frequency[
        if (random-float 1) < 0.8 [create-post self intent credibility]
      ]
    ]
  ]

   foreach micro-influencers [ turtle-id ->
    let actual-id item 0 turtle-id
    ask turtle actual-id[
      repeat 1 * posts-frequency[
        if (random-float 1) < 0.9 [create-post self intent credibility]
      ]
    ]
  ]

  foreach regular-influencers [ turtle-id ->
    let actual-id item 0 turtle-id
    ask turtle actual-id[
      repeat 1 * posts-frequency[
        if (random-float 1) < 0.6 [create-post self intent credibility]
      ]
    ]
  ]


end

;----------------- create the posts -----------

to create-post [current-turtle new-intent new-credibility]

  let my-incoming-links[]

  ; ask for all links to the influencer
  ask my-in-links [
    set my-incoming-links lput end1 my-incoming-links ; add all follower ids to list
  ]

  ; turtle creates post (turtle can be influencer or user which reposts)
  ask current-turtle [
    hatch-posts 1[
      set color red
      set size 0.5

      ; check if new coordinates are in world, else use coordinates of hatching agent
      let new-x (xcor + random 2)
      let new-y (ycor + random 2)

       ifelse new-x > max-pxcor
        [ set new-x max-pxcor ]
        [ if new-x < min-pxcor [set new-x min-pxcor]]

      ifelse new-y > max-pycor
        [ set new-y max-pycor]
        [ if new-y < min-pycor [ set new-y min-pycor]]

      setxy new-x new-y

      set origin-agent-id [who] of current-turtle ;
      set likes 0  ; number of likes
      set comment-average 0  ; average number of comments
      set comments 0 ;number of comments
      set reposts 0  ; number of reposts
      set intention new-intent  ; intention value of the post creator

      distribute-post current-turtle who
    ]

  ]
end

;----------------- distribute post in the network -----------

to distribute-post [outgoing-turtle post-id]

  let my-incoming-links[]

  ; collect follower of a turtle
  ask outgoing-turtle [
    ask my-in-links [set my-incoming-links lput end1 my-incoming-links]
  ]

  ; create a link from the post to each follower of the original turtle
  ask post post-id [
    foreach my-incoming-links [ [num] ->
      let new-link? false
      let post? false
      ask num [set post? breed = posts]

      ; if the following turtle hasn't a connection to the post already and is no post, the link is set between it and the post
      if (num != self) and (out-link-to num = nobody) and (post? = false)[
        create-posted-to num
        set new-link? true
        ; color turtle to show that is has a link to a post (= has seen it)
        ask num [
          if influencer? != true [set color magenta]
        ]

        ; if agent hasnt already seen post, it interacts with certain prob with it
        if (out-link-to num != nobody) and ((random-float 1) <= perceived-behavioral-control) and (new-link?)  [post-interaction num who]
        ; if (out-link-to num != nobody) and ((random-float 1) <= seeing-prob) and (new-link?)  [post-interaction num who] ; Experiment 3
      ]
    ]
  ]

end


; -----------------------------------------------------------------------------------------
; ------------------------------- post interaction ----------------------------------------
; -----------------------------------------------------------------------------------------

; ---------- interaction with post ---------------
to post-interaction [current-turtle post-id]

  ; set vars
  let reading-prob 0.7
  let interaction-impact 0
  let sim-intentions? compare-intentions? current-turtle post-id
  let interacted? false
  let post-distr-prob 0.7


  ; save post values locally
  let post-intention 0
  let current-comment-average 0
  let current-comments 0
  let current-likes 0
  let current-credibility 0
  let current-origin 0
  ask post post-id [
    set post-intention intention
    set current-comment-average comment-average
    set current-comments comments
    set current-likes likes
    set current-credibility credibility
    set current-origin origin-agent-id
  ]

  ; save turtle value locally
  let origin-influencer? 0
  ask turtle current-origin [set origin-influencer? influencer?]


  ; if agent is influencer, the impact of the post is higher
  let post-impact 0.1
  ifelse origin-influencer? = true
    [set post-impact 0.1]
    [set post-impact 0.05]

  ; save intention of agent locally and adjust social-norm based on intention of post
  let current-intent 0
  let turtle-credibility 0
  ask current-turtle [
    set current-intent intent
    set turtle-credibility credibility

    ; adapt social norm of receiving agent to social norm of sender (agent who posted post)
    if influencer? = 0 [set social-norm (social-norm + post-impact * (post-intention - social-norm))]
  ]

  ; increase impact of interaction and impressions of post
  set interaction-impact interaction-impact + 0.25
  ask post post-id [set impressions impressions + 1]


  ; ------------------  agent reads comments of post
  if (random-float 1) < reading-prob  [
    let comment-impact 0.05
    ask current-turtle [

      ;if there are comments, calculate the average intention
      if current-comments != 0 [
      let comment-intent (current-comment-average / current-comments)

        ; adjust the social norm (adapt to social norm of receiving agent to social norm of sender (agent who posted post))
        if influencer? = 0 [set social-norm (social-norm + comment-impact * (comment-intent - social-norm))]
      ]
    ]

    ; increase interaction impact if the intentions are similar, decrease otherwise
    ifelse sim-intentions?
      [set interaction-impact interaction-impact + 0.15]
      [set interaction-impact interaction-impact - 0.15]
  ]

  ; ------------------  agent likes post
  if (random-float 1) < liking-prob [
    ; increase interaction impact and number of likes and interactions of post
    set interaction-impact interaction-impact + 0.1
    ask post post-id [
      set likes (likes + 1)
      set interactions interactions + 1
    ]

    set interacted? true
  ]

  ; ------------------  agent comments post
  if (random-float 1) < commenting-prob [

    ; add the intention of agent to the counter and increase the comment count
    ; if the intention of post and agent is similar, increase interaction impact, otherwise decrease it
    ifelse sim-intentions?
    [
      set interaction-impact interaction-impact + 0.2
      ask post post-id [
        set comment-average (comment-average + current-intent)
        set comments (comments + 1)
        set interactions interactions + 1
      ]
      set current-comments (current-comments + 1)
   ][
      set interaction-impact interaction-impact - 0.2
      ask post post-id [
        set comment-average (comment-average + current-intent)
        set comments (comments + 1)
        set interactions interactions + 1
      ]
      set current-comments (current-comments + 1)
    ]

    set interacted? true
  ]

  ; -----------------------  agent shares post
  if (random-float 1) < (sharing-prob) [

    ; in- or decrease interaction impact based on intentions and increment repost counter and interaction count of post
    ifelse sim-intentions?
    [
      set interaction-impact interaction-impact + 0.3
      ask post post-id  [set reposts (reposts + 1) set interactions interactions + 1]]
    [
      set interaction-impact interaction-impact - 0.3
      ask post post-id [ set reposts (reposts + 1) set interactions interactions + 1]
    ]

    ; create new post and distribute it
    create-post current-turtle ((2 * current-intent + post-intention) / 3) ((2 * turtle-credibility + current-credibility) / 3)

    set interacted? true
  ]

  ; recalculate intention and adjust network based on the interaction
  recalculate-intention current-turtle interaction-impact post-intention current-origin sim-intentions?

  ; if agent has interacted with the post, distribute it with a certain probability to its network
  if (interacted?) and ((random-float 1) < post-distr-prob) [
    distribute-post current-turtle post-id
  ]

end

; -----------------------------------------------------------------------------------------
; ------------------------------- recalculation of intention ------------------------------
; -----------------------------------------------------------------------------------------

; -------- recalculation of agent specific values and network adjustments ------------
to recalculate-intention [current-turtle interaction-impact post-intention current-origin sim-intentions?]

  ask current-turtle [

    ; ------ attitude
    set attitude 0.5 * (env-awareness + interaction-impact) + 0.5 * (comfort)

    ; ------- pbc
    set perceived-behavioral-control (self-efficacy + conditions + interaction-impact) / 2

    ; ------- intention
    ; recalculate intention, social norm is not relevant for influencer
    ifelse influencer? = true
      [set intent (0.5 * attitude + 0.5 * perceived-behavioral-control) ]
      [set intent (0.5 * attitude + 0.5 * perceived-behavioral-control) * (1 - 0.3) + 0.3 * social-norm ]


    ; --------------------------- network

    ; if agent doesnt already follows influencer and if the intentions are similar, agent follows influencer with a certain probability
    if ((random-float 1) < follow-prob) and (out-link-to turtle current-origin = nobody and sim-intentions?) and (current-origin != who)  [
      create-followed-to turtle current-origin
    ]

    ; if agent follows influencer but the intentions are not (no longer) the same, agent unfollows influencer with certain probability
    if ((random-float 1) < unfollow-prob) and (out-link-to turtle current-origin != nobody and not(sim-intentions?))  [
      ask out-link-to turtle current-origin [die]
    ]
  ]
end

;----------------- compare intentions of post and influencer ---------------
to-report compare-intentions? [turtle-id post-id]
  ; This method returns true if the turtles intention is similar to the post intention
  let turtle-int 0
  let post-int 0
  ask turtle-id [set turtle-int intent]
  ask post post-id [set post-int intention]

  report abs(turtle-int - post-int) <= 0.4
end

; -----------------------------------------------------------------------------------------
; ------------------------------- report ---------------------------------------
; -----------------------------------------------------------------------------------------

; ------------ reports adoption rates ------------
to print-adoption-rates
  let count-non-a count turtles with [intent <= 0.4]
  let count-moderate count turtles with [intent > 0.4 and intent <= 0.6]
  let count-a count turtles with [intent > 0.6]

  ; Ausgabe der Ergebnisse
  print (word "Anzahl Turtles non-a: " count-non-a)
  print (word "Anzahl Turtles moderate: " count-moderate)
  print (word "Anzahl Turtles a: " count-a)
end

; ------------ reports link counts ------------
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

; ----- reports influencer and their follower counts --------
to print-influencer-count
  let cnt 0
  let all-followers []
  ask turtles [
    if influencer? = true [
          set cnt cnt + 1
          let num-links count my-in-links
          set all-followers fput num-links all-followers
          ;print(word cnt " and counted turtle " who " and influencer?: " influencer?)
    ]
  ]
  print (word "Number of influencer " cnt)
  set all-followers sort all-followers
  print(word "number of followers of influencer:" )
  print all-followers
end

; ------ reports distribution of initial attitude ------------
to print-initial-attitudes

  let count-0.2 count turtles with [initial-attitude = 0.2]
  let count-0.4 count turtles with [initial-attitude = 0.4]
  let count-0.6 count turtles with [initial-attitude = 0.6]
  let count-0.8 count turtles with [initial-attitude = 0.8]
  let count-1.0 count turtles with [initial-attitude = 1.0]


  print (word "Anzahl Turtles mit initial-attitude = 0.2: " count-0.2)
  print (word "Anzahl Turtles mit initial-attitude = 0.4: " count-0.4)
  print (word "Anzahl Turtles mit initial-attitude = 0.6: " count-0.6)
  print (word "Anzahl Turtles mit initial-attitude = 0.8: " count-0.8)
  print (word "Anzahl Turtles mit initial-attitude = 1.0: " count-1.0)
  print(word "übrige Agents "  length all-nodes)
end
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
60.0

SLIDER
850
25
1005
58
num-nodes
num-nodes
50
2000
1000.0
50
1
NIL
HORIZONTAL

SLIDER
850
60
1005
93
rewiring-probability
rewiring-probability
0
1
0.9
0.01
1
NIL
HORIZONTAL

BUTTON
10
10
85
50
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

TEXTBOX
850
10
1000
28
Networkvariables
11
0.0
1

BUTTON
95
10
172
50
go once
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

PLOT
10
75
315
280
Adoption rates
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"non-adopter" 1.0 0 -2674135 true "" "plot (count turtles with [intent <= 0.4]) / count turtles"
"adopter" 1.0 0 -13840069 true "" "plot (count turtles with [intent > 0.6]) / count turtles"
"moderate-interested" 1.0 0 -817084 true "" "plot (count turtles with [intent > 0.4 and intent <= 0.6]) / count turtles"

BUTTON
180
10
255
50
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

SLIDER
850
135
1005
168
liking-prob
liking-prob
0
0.3
0.048
0.001
1
NIL
HORIZONTAL

SLIDER
850
170
1005
203
commenting-prob
commenting-prob
0
0.3
0.024
0.001
1
NIL
HORIZONTAL

SLIDER
850
205
1005
238
sharing-prob
sharing-prob
0
0.3
0.002
0.001
1
NIL
HORIZONTAL

TEXTBOX
850
120
1000
138
Interaction-probabilities
11
0.0
1

SLIDER
850
265
1005
298
follow-prob
follow-prob
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
850
300
1005
333
unfollow-prob
unfollow-prob
0
1
0.05
0.05
1
NIL
HORIZONTAL

TEXTBOX
850
250
1000
268
Network-probabilities
11
0.0
1

TEXTBOX
855
350
1005
368
Random seed\n
11
0.0
1

INPUTBOX
855
365
1005
425
seed
2801.0
1
0
Number

SWITCH
855
430
1005
463
use-random-seed?
use-random-seed?
1
1
-1000

SLIDER
1040
25
1212
58
seeing-prob
seeing-prob
0
1
0.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
1040
10
1190
28
Post-frequency
11
0.0
1

SLIDER
1040
60
1212
93
posts-frequency
posts-frequency
1
20
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

The model is intended to be used to investigate innovation diffusion (ID) in social networks with the help of the Theory Of Planned Behavior (TPB).
The model represents an abstracted social network (X, former Twitter) in which posts are made by influencers with whom people interact. Based on these interactions, the intentions of the agents are then changed, which may or may not result in them adopting an innovation.

## HOW IT WORKS

The network setup is inspired by Kaufmann, P., et. al.: Simulating the diffusion of organic farming practices in two New EU Member States. Ecological Economics 68(10), 2580–2593 (Aug 2009) and is based on a modified version of the small-world model by Watts, D.J., Strogatz, S.H.: Collective dynamics of ‘small-world’ networks. Nature
393(6684), 440–442 (1998), which was expanded to include elements from preferential attachment from Barabasi, A.L., Albert, R.: Emergence of scaling in random networks. Science 286(5439), 509–512 (Oct 1999).

In each tick, posts are generated by influencers, distributed in the network and the agents interact with these posts. The aim is to analyze the changes in the intentions of the agents' intentions with regard to adaptation over time. In order to enable the presentation of the posts and the recording of all relevant interaction data, the “posts” breed was used. This object also makes it possible to establish connections between the agents and the posts as soon as an agent sees a post.
In the first step, all agents that have a direct connection to a influencer are linked to the post. As soon as these agents have interacted with the interact with the post, the post is forwarded to their direct neighbors with a certain probability.
forwarded to their direct neighbors, which simulates the dissemination process in the network. This diffusion of the posts lasts one tick at a time, so that with each new
each new tick, the previously generated posts are removed and replaced by new posts.
replaced by new posts. 


## HOW TO USE IT

Pressing the SETUP button initializes the model and is necessary for starting the simulation. 

With pressing of the GO-ONCE button, one tick of the simulation is executed.

With pressing of the GO button, the simulation runs until it is stopped by pressing again.


### Plots

The "Adoption rates" plot visualizes the state of adoption in the network by classification of agents into different groups: adopter, moderate interested and non-adopter.

### Network
The gray dotss are agents which aren't influencer, the blue ones are influencer. 
If a gray dot turns magenta after a tick, this means that one of the posts has reached it. The links that can be recognized after a tick are the connections between the posts and the agents who have seen them. The posts themselves are the small red dots


## THINGS TO TRY
There are various global variables that can be used to influence the model:
- num-nodes: number of agents in the model
- rewiring-probability: probability that an initial link to a neighbor is rewired to a random agent (with a certain probability an influencer)
- liking-prob: probability, that agent likes post distributed to her
- commenting-prob: probability, that agent comments post distributed to her
- sharing-prob: probability, that agent repostss post distributed to her
- use-random-reed?: determines, if random seed should be set by user or not
- seed: determination of the random seed which will be used (if set like this)
- seeing-prob: probabiliy with which the post will be distributed to the agent (to do this, one line in the code must be commented and the line below it commented out (“Experiment 3”)
- posts-frequency: factor with which the amount of posts the influencer post per tick can be changed



(note that the default values are the calibrated values)


## COPYRIGHT AND LICENSE

The starting point for the network implementation is Uri Wilensky's model "Small Worlds", which has been adapted to the specific requirements of this research and extended by the mapping of a social network.

Copyright 2015 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

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
  <experiment name="experiment" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>abs(reference value from real world data - measure (eg count turtles))</metric>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="influencer-link-prob">
      <value value="0.25"/>
      <value value="0.05"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="influencer-percentage">
      <value value="0.025"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-connected-neighbors">
      <value value="4"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment1" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / count turtles</metric>
    <metric>count turtles with [intent &lt;= 0.4] / count turtles</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / count turtles</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
    </enumeratedValueSet>
    <steppedValueSet variable="num-nodes" first="1000" step="250" last="2000"/>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment3_like" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / num-nodes</metric>
    <metric>count turtles with [intent &lt;= 0.4] / num-nodes</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / num-nodes</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
      <value value="0.096"/>
      <value value="0.144"/>
      <value value="0.192"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment3_comment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / num-nodes</metric>
    <metric>count turtles with [intent &lt;= 0.4] / num-nodes</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / num-nodes</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
      <value value="0.048"/>
      <value value="0.072"/>
      <value value="0.096"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment3_share" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / num-nodes</metric>
    <metric>count turtles with [intent &lt;= 0.4] / num-nodes</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / num-nodes</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
      <value value="0.004"/>
      <value value="0.006"/>
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment2" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / count turtles</metric>
    <metric>count turtles with [intent &lt;= 0.4] / count turtles</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / count turtles</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment3_read" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / count turtles</metric>
    <metric>count turtles with [intent &lt;= 0.4] / count turtles</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / count turtles</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seeing_Prob" first="0.5" step="0.1" last="1"/>
  </experiment>
  <experiment name="experimentALL" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>count turtles with [intent &gt; 0.6] / count turtles</metric>
    <metric>count turtles with [intent &lt;= 0.4] / count turtles</metric>
    <metric>count turtles with [intent &gt; 0.4 and intent &lt;= 0.6] / count turtles</metric>
    <enumeratedValueSet variable="sharing-prob">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="commenting-prob">
      <value value="0.024"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="unfollow-prob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="posts-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seeing_Prob">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-probability">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed">
      <value value="2801"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="liking-prob">
      <value value="0.048"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed?">
      <value value="false"/>
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
