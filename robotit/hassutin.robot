#!/usr/bin/tclsh8.6

set debugfile [open "/tmp/tclrobot-debug.txt"  "w"]
set eventfile [open "/tmp/tclrobot-events.txt" "w"]

proc tee {viesti} {
  debugmsg "Sending: $viesti"
  puts $viesti
}

proc debugmsg {viesti} {
  global debugfile
  puts $debugfile $viesti
}

proc komento {args} { proc {*}$args }

proc tapahtumat {tapahtumamääritelmät} {
  foreach {tapahtuma vars code} ${tapahtumamääritelmät} {
    proc $tapahtuma $vars $code
  }
}


# toimenpiteet

komento ammu     {voima} { tee "Shoot $voima"      }
komento jarrut   {voima} { tee "Brake $voima"      }
komento kiihdytä {voima} { tee "Accelerate $voima" }

komento käännä {mitä paljonko} {
  set choices {
    robottia 1
    kanuunaa 2
    tutkaa   4
  }

  if {[dict exists $choices ${mitä}]} {
    tee "Rotate [dict get $choices ${mitä}] $paljonko"
  }
}

komento lähetä.nimi {nimi} {
  tee "Name $nimi"
}


# vastaanotetut viestit


tapahtumat {
  alustus {onko_eka} {
    lähetä.nimi "Humppa pumppa"
  }

  koordinaatit {x y suunta} {
    käännä robottia $suunta
    kiihdytä 2
    # ammu 100
  }

  peli.alkaa {} {

  }

  peli.optio {mikä mitä} {

  }

  robotteja.jäljellä {montako} {

  }

  tutka {etäisyys mikä suunta} {
    käännä robottia $suunta
    käännä kanuunaa [expr { $suunta + 30 }]
    käännä tutkaa   $suunta
  }

  törmäys {mikä suunta} {
    jarruta 5
  }

  varoitus {mikä} {

  }
}

komento dispatch_event {event_type args} {
  set events {
    Collision   törmäys
    Coordinates koordinaatit
    GameOption  peli.optio
    GameStarts  peli.alkaa
    Initialize  alustus
    Radar       tutka
    RobotsLeft  robotteja.jäljellä
    Warning     varoitus
  }

  if {![dict exists $events $event_type]} {
    debugmsg "Unhandled event_type $event_type"
    return
  }

  [dict get $events $event_type] {*}$args
}

komento readevent {chan} {
  global debugfile
  global eventfile

  if {[eof $chan]} {
    close $debugfile
    close $eventfile
    exit 0
  } else {
    set eventline [gets $chan]
    puts $eventfile $eventline

    set event [list]
    foreach _ [split $eventline] { if {$_ ne ""} { lappend event $_ } }
    
    if {[llength $event] > 0} {
      if {[catch { dispatch_event {*}$event } err]} {
        debugmsg "SOME ERROR: $err"
      }
    }
  }
}

fileevent stdin readable [list readevent stdin]

vwait forever
