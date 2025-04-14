extensions [
  csv ; to upload config data from csv
  time ; to caluclate simulated time of day. displayed to user and used in sunset calc
  palette ; adds transperency to reduce link clutter
]
;### Declare Globals###
globals [
  BattleShipMagazineDmgBreakPoint ;imported and calculated from battleShipDamage.csv
  BattleShipEngineDmgBreakPoint   ;imported and calculated from battleShipDamage.csv
  BattleShipRudderDmgBreakPoint   ;imported and calculated from battleShipDamage.csv
  BattleShipTurretDmgBreakPoint   ;imported and calculated from battleShipDamage.csv
  TORPEDOSPEED
  TORPEDOLIFETIME
  TORPEDODAMAGE
  TORPEDOATTACKRANGE
  FleetInContact ;FALSE - out of contact or TRUE in contact
  SimTime ;Current date time within simulation
  SunSet ;Date time of SunSet
  NavalTwilight; Date time of end of aprox naval twilight (ie when Visibility from natural light is = 0)
  TicksUntilDarkness; Calculated value - number of ticks between Sunset (start of dusk) and Naval Twilight (Darkness)
  MaxVisibility; Current Maximum visual distance given lighting conditions, in patches
  VisibilityReductionStep; calculated amount per tick that Visible range (in patches) descreases between sunset and naval twilight
  CurrentBrightness ; global variable to hold the brighness of patches
  BrightnessReductionStep; calculated amount per tick that shade of patches descreases between sunset and naval twilight
  MINRUN; duration in ticks of minimum run
]

; ### Declare Agent Breeds ###
breed [turtleShips turtleShip]
breed [turtleTorpedoes turtleTorpedo]
breed [torpStart torpStarts] ;starting point for torpedo launch, used to create link visualizing torpedo track
undirected-link-breed [torpTracks torpTrack]
directed-link-breed [gunTracks gunTrack]

; ### Declare Agent Variables ###
turtleShips-own [
  shipId       ;Imported from orderOfBattle.csv
  name         ;Imported from orderOfBattle.csv
  fleet        ;Imported from orderOfBattle.csv
  enemyfleet   ;calculated
  shipBehaviour   ;Imported from orderOfBattle.csv
  twelveInchEquiv     ;Imported from orderOfBattle.csv
  destinationX ;Imported from orderOfBattle.csv
  destinationY ;Imported from orderOfBattle.csv
  maxTurn      ;Imported from orderOfBattle.csv
  speed        ;Imported from orderOfBattle.csv
  gunCaliber   ;Imported from orderOfBattle.csv
  maxGunRange  ;Imported from orderOfBattle.csv
  gunRateOfFire ;Imported from orderOfBattle.csv
  bowGuns      ;Imported from orderOfBattle.csv
  sternGuns    ;Imported from orderOfBattle.csv
  portGuns     ;Imported from orderOfBattle.csv
  starbGuns    ;Imported from orderOfBattle.csv
  torpedoTubes ;Imported from orderOfBattle.csv
  shipLength   ;Imported from orderOfBattle.csv
  shipBeam     ;Imported from orderOfBattle.csv
  hullPoints   ;Imported from orderOfBattle.csv
  damageTakenThisTick  ;calculated.
  lostHp       ;amount of HP ship has lost from max hp
  inContactWithEnemy ;True if enemy is within visual range
  sunk         ;calculated, 0=unsunk 1=sunk
  shipType
  shipClass
]

turtleTorpedoes-own [
  fleet ;set to Torpedo
  speed ;set to Global var TORPEDOSPEED
  lifetime ;set to Gloval var TORPEDOLIFETIME
  detonated ;calculated 0 for undetonated, 1 for detonated
]


;### Procedures that run on setup. ###

to setup-constants
  set TORPEDOSPEED 3
  set TORPEDOLIFETIME 19
  set TORPEDODAMAGE 9
  Set TORPEDOATTACKRANGE 40
  Set FleetInContact TRUE
  set SimTime time:anchor-to-ticks (time:create "1916/05/31 20:15") 40 "second"
  set SunSet time:create "1916/05/31 20:43" ; Starts getting dark time. 20:43 is 30 min before TrueSunset of 21:13 based on sun calc and latitude
  set NavalTwilight time:create "1916/05/31 21:13"; Finishes getting dark time. Much earlier than true naval twilight, which doesnt actually occur that far north in may
  set MaxVisibility 80 ;Best guess based off 20:05 max range of german battlecruiser salve Tarrant p153
  set TicksUntilDarkness ( time:difference-between (Sunset) (NavalTwilight) "seconds" / 40 ) ;number of seconds between sunset and darkness / sec per tick
  set VisibilityReductionStep (MaxVisibility / ticksUntilDarkness)
  set MINRUN 30


  resize-world -180 160 -150 45 ;sets patch size of the world.

end

to setup-patches
  ask patches [ set pcolor blue ]
  set CurrentBrightness [palette:brightness] of patch 0 0
  set BrightnessReductionStep ( CurrentBrightness / (2 / 3 * ticksUntilDarkness)) ; cosmetic brightness of patches is reduced between sunset and naval twilight

  ;PLACEHOLDER SETUP FOR INITIAL PATCH OPACITY FOR GUNNERY MODEL GOES HERE
end

to setup-turtleShips
  ;load the attributes of ships and their fleet from the orderOfBattle.csv
  file-close-all ;protects against unfinished setups that kept csv locked

  file-open "orderOfBattle.csv"
  if debug [print "=== Loading Ships from orderOfBattle.csv ==="]
  let csvHeadings csv:from-row file-read-line
  if debug [print csvHeadings]
  while [not file-at-end?][
    ;for each record of csv, create the specified ship
    let rowdata csv:from-row file-read-line
    if debug [print rowdata]
    create-turtleShips 1[
      set shipId item 0 rowdata
      set xcor item 1 rowdata
      set ycor item 2 rowdata
      set heading item 3 rowdata ; Azimuth 0-360
      set name item 4 rowdata ; name of ship as string
      set fleet item 5 rowdata ; str: "British" or "German"
      set shipBehaviour item 6 rowdata; str: "Battleship" or "Destroyer" determines behaviour in sim
      set twelveInchEquiv item 7 rowdata ; Primary armament equivalent in 12 inch rounds (850lbs), based on projectile weight
      set destinationX item 8 rowdata ; xcor of destination patch
      set destinationY item 9 rowdata ; ycor of destination patch
      set maxTurn item 10 rowdata ; max ship can turn in degrees per tick
      set speed item 11 rowdata ; speed ship moves - patches per tick
      set gunCaliber item 12 rowdata ;Primary weapon calbier in inches. Not used in Sim, information only
      set maxGunRange item 13 rowdata ; max range of gun in patches
      set gunRateOfFire item 14 rowdata ; rate of fire, shots per tick
      set bowGuns item 15 rowdata ; number of guns with arc b/w -90 and 90 degrees
      set sternGuns item 16 rowdata ; number of guns with arc b/w 90 and 270 degrees
      set portGuns item 17 rowdata ; number of guns with arc b/w 180 and 360 degrees
      set starbGuns item 18 rowdata; number of guns with arb b/w 0 and 180 degrees
      set torpedoTubes item 19 rowdata ;placeholder need to figure out how to encode and parse torp tubes
      set shipLength item 20 rowdata ;length in meters. Used for torpedo detonation chance.
      set shipBeam item 21 rowdata ; beam (width) in meters. Used for torpedo detonation chance.
      set hullPoints item 22 rowdata
      set shipType item 23 rowdata
      set shipClass item 24 rowdata
      set sunk 0
      set damageTakenThisTick 0
      set lostHp 0
    ]
  ]
  file-close-all

  ;Set up visuals for fleets
  ask turtleShips[
    if fleet = "British"[
      ;set up visuals of British Fleet
      set color red + 3 ;placeholder
      set enemyFleet "German" ;populated calculated attribute
    ]
    if fleet = "German"[
      ;set up visuals of German Fleet
      set color yellow + 3 ;placeholder
      set enemyFleet "British"
    ]
    if shipType = "destroyer" [
      set shape "arrow"
      set size 2
    ]

     if shipType = "battlecruiser" [
      set size 5
      set shape "battlecruiser"
    ]

    if shipType = "cruiser" [
      set size 3.4
      set shape "cruiser"
    ]

    if shipType = "battleship" [
      set size 5
    ]
    palette:set-alpha 190

  ]
end

to load-DamageGlobals
  ;loads the chances of sustaining crtical damage and converts to breakpoints

  file-close-all ;protects against unfinished setups that kept csv locked
  if debug [print "=== Loading Damage Breakpoints from *Class*Damage.csv ==="]

  if debug [print "loading Battleship Damage Breakpoints"]
  file-open "battleShipDamage.csv"
  let csvHeadings csv:from-row file-read-line
  if debug [print csvHeadings]
  let rowdata csv:from-row file-read-line
  set BattleShipMagazineDmgBreakPoint item 1 rowdata
  set BattleShipEngineDmgBreakPoint (item 2 rowdata + BattleShipMagazineDmgBreakPoint)
  set BattleShipRudderDmgBreakPoint (item 3 rowdata + BattleShipEngineDmgBreakPoint)
  set BattleShipTurretDmgBreakPoint (item 4 rowdata + BattleShipRudderDmgBreakPoint)
  if debug [print (list  BattleShipMagazineDmgBreakPoint BattleShipEngineDmgBreakPoint BattleShipRudderDmgBreakPoint BattleShipTurretDmgBreakPoint )]
  file-close-all
end

;### Procedures that run on tick. ###

to move-turtleTorpedoes
  ask turtleTorpedoes[
    ;move forward one square at a time, checking for ships on same patch
    repeat speed[
      forward 1
      if detonated = 0 [
        let shipsInDanger turtleShips-here
        let shipSufferingDetonation nobody ;awkward helper var to record successful detonation. Used to accomodate turtle context.
        ask shipsInDanger [
          ;for each ship in same patch, check for torpedo detonation. If detonation occurs, set interim shipSuffering Variable
          ifelse checkForDet self myself [
            set shipSufferingDetonation self
          ]
          [ if debug [print word [name] of self " has narrowly evaded torpedoes"]]
        ]
        if shipSufferingDetonation != nobody [
          if debug [print word [name] of shipSufferingDetonation " has been hit by a torepedo!"]
          ask shipSufferingDetonation [set damageTakenThisTick damageTakenThisTick + TORPEDODAMAGE]
          set detonated 1
        ]
      ]
    ]
    ; decrement lifetime
    set lifetime lifetime - 1
    if (lifetime <= 0) or (detonated = 1) [
      ask in-torpTrack-neighbors [ die ] ;kill hidden torpStart agent linked to torp
      die ]

  ]
end

to-report checkForDet [shipAgent torpAgent]
 ;Takes ship agent and torp agent. Calculates prob of collision based on their orientation,
 ;determines if ship is hit. returns bool.
  let theta subtract-headings [heading] of shipAgent [heading] of torpAgent
  let lterm abs  sin theta * [shipLength] of shipAgent
  let numerator max ( list lterm [shipBeam] of shipAgent )
  let pVal numerator / 200
  report random-float 1 <= pVal
end



to-report getDistance [agent1 agent2]
  ;a helper function to report the distance between 2 agents
  let returnval nobody
  ask agent1[
    set returnval distance agent2
  ]
  report returnVal
end


to move-turtleShips
  ;Move the turtleShips in 3 steps:
  ;1-Determine Desired destination
  ;2-adopt desired heading subject to turn rate
  ;3-move ships forward

  ;German Battleships setting destination to southern edge at GermanTurnTime,
  if ticks = GermanDisengageSignalTick[ ; value set by slider, run once (destinations static)
    if debug [print word  ticks ":German Admiral Scheer Signals for withdrawal by individual movement"]

    ask turtleShips with [fleet = "German" and shipBehaviour = "Battleship"][
      set destinationX min-pxcor + 45 ;offset causes ships to turn to port per historical example
      set destinationY min-pycor

    ]
  ]
  if ticks > GermanDisengageSignalTick + 10 [
    ask turtleShips with [fleet = "German" and shipBehaviour = "Battleship"][
      set destinationX min-pxcor
      set destinationY min-pycor
    ]
  ]
  ;German destroyers either a)close with closest taget and fire torepedoes or b) withdraw if no torpedoes
  ;run every tick >= of german signal, destinations are dynamic

  if ticks >= GermanDisengageSignalTick[
    ask turtleShips with [fleet = "German" and shipBehaviour = "Destroyer"][
      if torpedoTubes > 0[
        ;if Destroyers have torpedoes, close with nearest battleship

        ; finds closest hostile
        let possibleTargets turtleShips with [fleet = "British" and shipType = "Battleship"]


        let closestTarget min-one-of possibleTargets [distance myself]

        ;set desired destination to target location
        if closestTarget != nobody [
          let targetPatch lead-Target closestTarget [speed] of self
          set destinationX [pxcor] of targetPatch
          set destinationY [pycor] of targetPatch
        ]
      ]
     if torpedoTubes <= 0[
       ;if destroyers have no torpedoes, withdraw
       set destinationX min-pxcor
       set destinationY min-pycor
      ]
    ]

  ]

  ;After GermanTurnTime+Delay, British adjust course, either closing with closest german or turning away
  if ticks > GermanDisengageSignalTick + BritishDelay [ ;british delay set by slider

    if BritishSignal = "Engage"[;BritishSignal Set by User via chooser

      let possibleTargets turtleShips with [fleet = "German" and shipBehaviour = "Battleship"]
      ask turtleShips with [fleet = "British"][
        ;let closestTarget min-one-of possibleTargets [distance myself]
        let closestTarget min-one-of possibleTargets [distance myself] ; finds closest hostile
        ;set destination to postion of closest hostile
        if closestTarget != nobody [
         set destinationX [xcor] of closestTarget
         set destinationY [ycor] of closestTarget
        ]
      ]
    ]

    if britishSignal = "Disengage" [;   BritishSignal Set by User via chooser
      ;define behaviour of british ships if signal is "Disengage"
      ;let hostiles turtleShips with [fleet != "British"] ;get the set of things to evade

     ; if any? hostiles [
        ask turtleShips with [fleet = "British"] [
;          let closestHostile min-one-of hostiles [distance myself] ; finds closest hostile
;          let hostilesDestination patch [xcor] of closestHostile [ycor] of closestHostile
;          show hostilesDestination
;          let hostileDistToDest getdistance closestHostile hostilesDestination
;          if hostileDistToDest > distance hostilesDestination [ ;if ship is not between hositle and its detination
;            set destinationX [destinationX] of closestHostile ;placeholder, NEED TO FIGURE OUT EVASION SUBTRACT HEADING? IF torpedo match heading if ship head away
;            set destinationY [destinationY] of closestHostile
;          ]
;          if hostileDistToDest <= distance hostilesDestination [ ; if ship is between target and its destination
;            set destinationX [0 - destinationX] of closestHostile ;placeholder, NEED TO FIGURE OUT EVASION SUBRTACT HEADING?
;            set destinationY [0 - destinationY] of closestHostile
;          ]
          set destinationX max-pxcor
          set destinationY ycor
        ]
;      ]
    ]
  ]

  ;set  the desiredHeadingChange to be the difference between destination
  ;and current heading subject to max turn
  ask turtleShips [
    let desiredHeadingChange subtract-headings towardsxy destinationX destinationY heading
    if desiredHeadingChange > maxturn[
      right maxturn]
    if desiredHeadingChange < 0 - maxturn [
      right 0 - maxturn ]
    if (desiredHeadingChange < maxturn) and (desiredHeadingChange > 0 - maxturn )[
      right desiredHeadingChange]

    ;try to move ships along their modified heading. If desired patch is occupied, slow by 1 and try again
    let checkSpeed speed
    let desiredOccupied True
    let checkedSpeed 0
    carefully [
      while [(desiredOccupied = True) and (checkSpeed > 0)] [
        if (count other turtleShips-on patch-ahead checkSpeed = 0 )[
          set desiredOccupied False
          set checkedSpeed checkSpeed
        ]
        set checkSpeed checkSpeed - .3
      ]
    ]
    [ ]
    forward checkedSpeed
  ]
end

to-report lead-Target [targetedAgent projectileSpeed]
  ;takes agent and the speed of projectile in patches. returns the patch that results in intercept course.
  ;assumes constant heading and speed
  let targetPatch nobody
  let timeToTarget distance targetedAgent / projectileSpeed
  let offset timeToTarget * [speed] of targetedAgent
  ask targetedAgent [set targetPatch patch-at-heading-and-distance [heading] of targetedAgent offset]
  report targetPatch
end

to-report lead-TargetTorpedoes [targetedAgent projectileSpeed]
  ;takes agent and the speed of projectile in patches. returns the patch that results in intercept course.
  ;assumes constant heading and speed. Adjusted for torpedo movement occuring before ship movement
  let targetPatch nobody
  let timeToTarget (distance targetedAgent / projectileSpeed) - 1
  let offset timeToTarget * [speed] of targetedAgent
  ask targetedAgent [set targetPatch patch-at-heading-and-distance [heading] of targetedAgent offset]
  report targetPatch
end

to launch-turtleTorpedoes
  ask turtleShips[
      if torpedoTubes > 0 [
      let reps torpedoTubes
      let enemyBattleShips turtleShips with [ fleet = [enemyFleet] of myself and shipBehaviour = "Battleship" ] ;create agentset of all enemies
      ;let targetShip min-one-of enemyBattleShips [distance myself]
      let targetShip one-of enemyBattleShips
      if targetShip != nobody [
        if distance targetShip <= TORPEDOATTACKRANGE[
          let targetPatch lead-targetTorpedoes targetShip TORPEDOSPEED
          ;PLACEHOLDER FOR OFFSET CALCULATION TO SIMULATE BEST EFFORTS OF CREW TO LEAD TARGET
          let torpHeading towards targetPatch
          let newtorp nobody
          repeat reps[
            ask patch-here[
            sprout-turtleTorpedoes 1 [
              set heading torpHeading
              set fleet "Torpedo"
              set speed TORPEDOSPEED
              set lifetime TORPEDOLIFETIME
              set shape "line half"
              set color white
              set newtorp self
              ]

            ;create a hidden agent to draw torpedo track to
            sprout-torpStart 1 [
              create-torpTrack-with newtorp
              set hidden? True
              ]
            ]
            set torpedoTubes -1
          ]
        ]
      ]
    ]
  ]
end

to shoot-turtleShips
;procedure leverages built in cone function to target neares in arc enemy.
;Abuses heading by spinning the turtle in place to fire each orientation of turrets.
;rotates 360 within a tick to maintain 'real' heading.

  ask turtleShips[
    let enemyShips turtleShips with [ fleet = [enemyFleet] of myself ] ;create agentset of all enemies
    let effectiveRange min list MaxVisibility maxGunRange
    ;bow guns: find enemies and fire turrents
    let enemyInArc enemyShips in-cone  effectiveRange 180   ;agentset of enemy in arc

    ;Orignally selected closest enemy in arc per below, but results were overly coordinated shooting that sniped ships too effectively
    ;let targetShip min-one-of enemyInArc [distance myself] ; finds closest enemy in arc

    ;shoot bow guns
    let targetShip one-of enemyInArc  ;Selects a random enemy in arc and in effective range
    if targetShip != nobody [ fireTurrets targetShip [bowGuns] of self]
    ;shoot starboard guns
    right 90
    set enemyInArc enemyShips in-cone  effectiveRange 180   ;agentset of enemy in arc
    set targetShip one-of enemyInArc
    if targetShip != nobody [ fireTurrets targetShip [starbGuns] of self]
    ;shoot stern guns
    right 90
    set enemyInArc enemyShips in-cone  effectiveRange 180   ;agentset of enemy in arc
    set targetShip one-of enemyInArc  ; finds closest enemy in arc
    if targetShip != nobody [ fireTurrets targetShip [sternGuns] of self]
    ;shoot port guns
    right 90
    set enemyInArc enemyShips in-cone  effectiveRange 180   ;agentset of enemy in arc
    set targetShip one-of enemyInArc
    if targetShip != nobody [ fireTurrets targetShip [portGuns] of self]
    ;turn back to original heading
    right 90
  ]
end

to fireTurrets [targetShip gunsInArc]

  create-guntrack-to targetShip
  ;determine expected number of hits. Fractional hits ok.
  let hitsOnTarget ( gunRateOfFire * twelveInchEquiv * gunsInArc * 0.02 )  ;PLACEHOLDER FOR GUNNERY MODEL 3% of shots fired at jutland hit. 1% penalty as placeholder for dusk and smoke
  ;add more complicated fromula based on hit distribution per "An analysis of the fighting". Some relevant variables are likely range and illumination/smoke

  ask patch-here [set pcolor grey] ;placeholder for now, creates patch of grey. could generate smoke once implemented

  ;accumulate expected hits to "damageTakenThisTick" field for resolution at end of tick
  ask targetShip [
    set damageTakenThisTick ( [damageTakenThisTick] of self + hitsOnTarget )

    ;placeholder for smoke generation on being hit.
    ;set pcolor pink
  ]


end

to damage-turtleShips
  ;resolve expected hits on TurtleShips
  ask turtleships [
    ;calculate discrete hits for purposes of assigning critical damage
    let partialHits [damageTakenThisTick] of self mod 1
    let discreteHits floor [damageTakenThisTick] of self
    ;account for partial hits by giving them a prorated chance of inclusion
    if partialHits >= random-float 1 [set discreteHits discreteHits + 1]
    ;for each hit, check for critical damage
    repeat discreteHits [checkForCriticalDamage]

    ;reduce hullpoints and reset DamageTakenThisTick
    set hullPoints ( [hullPoints] of self - [damageTakenThisTick] of self  )
    set lostHp ([lostHp] of self + [damageTakenThisTick] of self )
    if hullPoints <= 0 [
      if debug [show word [name] of self " has been taken out of action by cumulative damage"]
      set sunk 1
    ]
    if sunk = 1 [
      ifelse fleet = "British"[
        set color green
      ][
        set color red
      ]
      sink-TurtleShip
    ]
  ]
end

to sink-TurtleShip
  set shape "fire"
  if fleet = "British"[ set color red ]
  if fleet = "German"[ set color lime ]
  if cosmetics = True[
    stamp
  ]
  die
end

to checkForCriticalDamage
  ;check for crit by comparing a random float and comparing it against Global dmg breakpoints
  let randNum random-float 1
  if [shipBehaviour] of self = "Battleship" [
    ;compare random float to Battleship dmg breakpoints
    (ifelse        ;hideous syntax of if..elif block
      randNum <= BattleShipMagazineDmgBreakPoint [sufferExplosion]
      randNum <= BattleShipEngineDmgBreakPoint [sufferEngineRoomHit]
      randNum <= BattleShipRudderDmgBreakPoint [sufferRudderHit]
      randNum <= BattleShipTurretDmgBreakPoint [sufferTurretHit]
      [ ;show word [name] of self " has suffered a non-disabling hit"
      ] ;last block is executed if all boolean statements are true. Hideous.
    )
   ]

  ;currently destroyers dont take critical hits. If research reveals that partially disabled destroyers were a factor we can add
end

to sufferExplosion
  set damageTakenThisTick hullPoints
  if debug [show word [name] of self " has suffered a catastophic explosion!"]
end

to sufferEngineRoomHit
  let reducedSpeed max (list 0 ([speed] of self / 2))
  set speed reducedSpeed
  if debug [show word [name] of self " has suffered a disabling hit to an engine room"]
end

to sufferRudderHit
  let reducedMaxTurn max (list 0 ([maxTurn] of self / 2 ))
  set maxturn reducedMaxTurn
  if debug [show word [name] of self " has suffered a disabling hit to her rudder"]
end

to sufferTurretHit
  if debug [show word [name] of self " has suffered a disabling hit to one of her turrets"]
  let randNum random 4
  (ifelse
    randNum = 0 [ set bowGuns max (list 0 ([bowGuns] of self - 2 ))]
    randNum = 1 [ set sternGuns max (list 0 ([bowGuns] of self - 2 ))]
    randNum = 2 [ set portGuns max (list 0 ([bowGuns] of self - 2 ))]
               [ set starbGuns max (list 0 ([bowGuns] of self - 2 ))]
  )
end

to reduce-visibility
  ;if simtime is after sunset, reduce max visibility by calculated amount
  if time:is-between? Simtime Sunset NavalTwilight [
    set MaxVisibility max (list 0 (MaxVisibility - VisibilityReductionStep))
    ;darken colors of patches by precalculated increment.
    ;calculated globally to avoid world width * world length redundant calcs.

    ;decrement CurrentBrightness
    set CurrentBrightness max (list 0 (CurrentBrightness - BrightnessReductionStep))

    ask patches[
      palette:set-brightness CurrentBrightness
    ]
  ]
end

to set-FleetInContact
  ;if no ship is within MAXVISIBILITY of enemy ship, FleetInContact is set to False. This triggers end of simulation in Behaviour Space tool
  ask turtleships [
    let enemyShips turtleShips with [ fleet = [enemyFleet] of myself ]
    let closestEnemy min-one-of enemyShips [distance myself]
    (ifelse
      closestEnemy = nobody [ set inContactWithEnemy FALSE ] ;if no enemies remaining, ship has broken contact
      distance closestEnemy > MaxVisibility [ set inContactWithEnemy FALSE ]  ;if closes enemy is beyond visual range, ship has broken contact
      [set inContactWithEnemy TRUE ] ;else ship remains in contact
    )
  ]
  if all? turtleships [inContactWithEnemy = FALSE] [set FleetInContact FALSE] ;if no ships are in contact with enemy fleet is out of contact
end

to set-cosmetics
  ;utility process run at end of of on-tick loop to alter any cosmetic values before being displayed to user.
  ask gunTracks [palette:set-alpha 50]
  ask torpTracks [
    set color white
  ]
end


;### The orchestrating Main procedures ###
to setup
  clear-all
  setup-constants
  setup-patches
  setup-turtleShips
  load-DamageGlobals
  reset-ticks
end

to go
  while [FleetInContact or ticks < MINRUN]
  [
    if cosmetics = False[
      ask links[
        set hidden? True
      ]
    ]
    ask gunTracks [die]
    ask turtleships [set damageTakenThisTick 0]
    move-turtleTorpedoes
    move-turtleShips
    launch-turtleTorpedoes
    shoot-turtleShips
    damage-turtleShips
    reduce-visibility
    set-FleetInContact
    set-cosmetics
    tick
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1582
803
-1
-1
4.0
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
160
-150
45
1
1
1
ticks
30.0

BUTTON
31
20
100
53
Setup
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
111
20
174
53
Go
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
0
59
208
92
GermanDisengageSignalTick
GermanDisengageSignalTick
0
10
0.0
1
1
Tick
HORIZONTAL

SLIDER
1
104
205
137
BritishDelay
BritishDelay
0
15
3.0
1
1
Tick
HORIZONTAL

CHOOSER
33
147
171
192
BritishSignal
BritishSignal
"Disengage" "Engage"
0

PLOT
6
204
206
354
Fleet Hull Points 
time
totals
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"British" 1.0 0 -5298144 true "" "plot sum [hullPoints] of turtleShips with [fleet = \"British\"]"
"German" 1.0 0 -16777216 true "" "plot sum [hullPoints] of turtleShips with [fleet = \"German\"]"

MONITOR
8
366
204
411
SimTime
time:show SimTime \"yyyy-MM-dd HH:mm:ss\"
2
1
11

MONITOR
8
417
204
462
Fleets In Contact
FleetInContact
17
1
11

SWITCH
37
523
170
556
debug
debug
1
1
-1000

SWITCH
38
564
171
597
cosmetics
cosmetics
0
1
-1000

MONITOR
7
468
203
513
Visibility (Meters)
MaxVisibility * 200
0
1
11

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
Polygon -16777216 true false 150 15 120 90 180 90

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150
Polygon -16777216 true false 150 15 150 15 90 90 210 90

battlecruiser
true
0
Polygon -7500403 false true 45 255 150 15 255 255 150 225
Polygon -16777216 true false 150 15 120 105 180 105

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

cruiser
true
0
Polygon -7500403 false true 105 285 105 150 0 150 150 0 300 150 195 150 195 285
Polygon -16777216 true false 150 15 105 60 180 60 195 60

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

fire
false
0
Polygon -7500403 true true 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -7500403 true true 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Demo" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="BritishDelay">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="GermanDisengageSignalTick">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="BritishSignal">
      <value value="&quot;Engage&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Monte Carlo" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="70"/>
    <exitCondition>"FleetInContact" = FALSE</exitCondition>
    <metric>time:show SimTime "HH:mm:ss"</metric>
    <metric>count turtleShips with [fleet = "British"]</metric>
    <metric>count turtleShips with [fleet = "British" and shipType ="destroyer"]</metric>
    <metric>count turtleShips with [fleet = "British" and shipType ="battlecruiser"]</metric>
    <metric>count turtleShips with [fleet = "British" and shipType ="cruiser"]</metric>
    <metric>count turtleShips with [fleet = "British" and shipType ="battleship"]</metric>
    <metric>sum [hullPoints] of turtleShips with [fleet = "British"]</metric>
    <metric>sum [damageTakenThisTick] of turtleShips with [fleet = "British"]</metric>
    <metric>sum [bowGuns + sternGuns + portGuns + starbGuns] of turtleShips with [fleet = "British"]</metric>
    <metric>count turtleShips with [fleet = "German"]</metric>
    <metric>count turtleShips with [fleet = "German" and shipType ="destroyer"]</metric>
    <metric>count turtleShips with [fleet = "German" and shipType ="battlecruiser"]</metric>
    <metric>count turtleShips with [fleet = "German" and shipType ="cruiser"]</metric>
    <metric>count turtleShips with [fleet = "German" and shipType ="battleship"]</metric>
    <metric>sum [hullPoints] of turtleShips with [fleet = "German"]</metric>
    <metric>sum [damageTakenThisTick] of turtleShips with [fleet = "German"]</metric>
    <metric>sum [bowGuns + sternGuns + portGuns + starbGuns] of turtleShips with [fleet = "German"]</metric>
    <enumeratedValueSet variable="debug">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="BritishDelay" first="0" step="1" last="10"/>
    <steppedValueSet variable="GermanDisengageSignalTick" first="0" step="1" last="15"/>
    <enumeratedValueSet variable="BritishSignal">
      <value value="&quot;Engage&quot;"/>
      <value value="&quot;Disengage&quot;"/>
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
