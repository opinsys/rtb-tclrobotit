#!/usr/bin/tclsh8.6

set robottitiedosto [lindex $argv 0]

if {$robottitiedosto eq ""} {
  puts stderr "No robotfile given, exiting!"
  exit 1
}


# XXX these should be disabled in production
set debugfile [open "/tmp/tclrobot-debug.txt"  "w"]
set eventfile [open "/tmp/tclrobot-events.txt" "w"]


proc komento {args} { proc {*}$args }

komento lähetä {viesti} {
  debugmsg "Sending: $viesti"
  puts $viesti
}

komento aseta {muuttuja arvo} {
  uplevel 1 set $muuttuja $arvo
}

komento muista {args} {
  foreach var $args { uplevel 1 global $var }
}

komento älä {args} {}

komento jos {args} { uplevel 1 if $args }

komento laske {args} { uplevel 1 expr $args }

komento debugmsg {viesti} {
  global debugfile
  puts $debugfile $viesti
}

komento lue_tiedosto {polku} {
  set fd [open $polku]
  set robotdata [read $fd]
  close $fd
  return $robotdata
}

komento tapahtumat {tapahtumamääritelmät} {
  # XXX these should be run in the safe interpreter
  foreach {tapahtuma vars code} ${tapahtumamääritelmät} {
    proc $tapahtuma $vars $code
  }
}


# toimenpiteet

komento ammu {{voima 5}} {
  lähetä "Shoot $voima"
}

komento jarruta {{voima 5}} {
  kiihdytä 0
  lähetä "Brake $voima"
}

komento kiihdytä {{voima 5}} {
  lähetä "Accelerate $voima"
}

komento etsi {kulma} {
  set miinuskulma [format %.2f [laske { - $kulma }]]
  set pluskulma   [format %.2f [laske {   $kulma }]]

  # lähetä "Sweep ${millä} ${nopeus} ${oikea.kulma} ${vasen.kulma}"
  lähetä "Sweep 6 1 $miinuskulma $pluskulma"
}

komento etsi.kapeasti  {} { etsi 0.785 }
komento etsi.laajalti  {} { etsi 2.36  }

komento lopeta {mikä} {
  switch -- ${mikä} {
    etsintä {
      etsi 0.0
      käännä.suhteessa.robottiin {tykkiä tutkaa} suoraan
    }
  }
}

komento käännä {mitä paljonko} {
  lähetä.kääntö Rotate ${mitä} $paljonko
}

komento käännä.suhteessa.robottiin {mitä paljonko} {
  lähetä.kääntö RotateTo ${mitä} $paljonko
}

komento käännösluku {paljonko} {
  format %.3f [
    switch -- $paljonko {
      vasemmalle { expr { 1}  }
      suoraan    { expr { 0}  }
      oikealle   { expr {-1}  }
      default    { expr {$paljonko} }
    }
  ]
}

komento käännösobjektinumero {mitä} {
  set choices {
    robottia 1
    tykkiä   2
    tutkaa   4
  }

  set numero 0
  foreach m ${mitä} {
    if {[dict exists $choices $m]} {
      incr numero [dict get $choices $m]
    }
  }

  return $numero
}

komento käänny {paljonko} {
  käännä {robottia tykkiä tutkaa} $paljonko
}

komento lähetä.kääntö {komento mitä paljonko} {
  set n [käännösobjektinumero ${mitä}]
  set r [käännösluku $paljonko]
  lähetä "$komento $n $r"
}

komento nimi {nimi} {
  lähetä "Name $nimi"
}

komento värit {värit} {
  lähetä "Colour ${värit}"
}

komento tutka {etäisyys mikä suunta} {
  switch -- ${mikä} {
    0 { tutkassa.robotti ${etäisyys} ${suunta} }
    1 { tutkassa.ammus   ${etäisyys} ${suunta} }
    2 { tutkassa.seinä   ${etäisyys} ${suunta} }
    3 { tutkassa.nami    ${etäisyys} ${suunta} }
    4 { tutkassa.miina   ${etäisyys} ${suunta} }
  }
}

komento törmäys {mikä suunta} {
  switch -- ${mikä} {
    0 { törmättiin.robottiin $suunta }
    1 { törmättiin.ammukseen $suunta }
    2 { törmättiin.seinään   $suunta }
    3 { törmättiin.namiin    $suunta }
    4 { törmättiin.miinaan   $suunta }
  }
}

komento viestitä {sisältö} {
  puts "Print ${sisältö}"
}

# vastaanotetut viestit


tapahtumat [lue_tiedosto $robottitiedosto]

komento dispatch_event {event_type args} {
  set events {
    Collision       törmäys
    Coordinates     koordinaatit
    Dead            kuolin
    Energy          energiataso
    ExitRobot       lopetus
    GameFinishes    peli.loppuu
    GameOption      peli.optio
    GameStarts      peli.alkaa
    Info            omia.tietoja
    Initialize      alustus
    Radar           tutka
    RobotsLeft      robotteja.jäljellä
    RobotInfo       toisen.robon.tietoja
    RotationReached suunta.saavutettu
    YourColour      värisi
    YourName        nimesi
    Warning         varoitus
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
        debugmsg "Virhe käsiteltäessä $event: $err"
      }
    }
  }
}

fileevent stdin readable [list readevent stdin]

vwait forever
