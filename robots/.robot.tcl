#!/usr/bin/tclsh8.6

set scriptpath [file normalize $argv0]

set scriptdir  [file dirname $scriptpath]
set scriptname [file tail $scriptpath]

set robottitiedosto \
  "[file dirname $scriptdir]/robotit/[file rootname $scriptname].robotti"

if {![file exists $robottitiedosto]} { exit 0 }


global robotin_username
set robotin_username [file rootname [file tail $robottitiedosto]]

global robot_ok

interp create -safe robotinterp

interp share "" stdin  robotinterp
interp share "" stdout robotinterp
interp share "" stderr robotinterp


robotinterp eval {
  proc komento {args} { proc {*}$args }

  komento lähetä {viesti} {
    puts $viesti
  }

  komento aseta {muuttuja arvo} {
    uplevel 1 set [list $muuttuja $arvo]
  }

  komento muista {args} {
    foreach var $args { uplevel 1 global $var }
  }

  komento älä {args} {}

  komento jos {args} { uplevel 1 if $args }

  komento laske {args} { uplevel 1 expr $args }

  komento robottikoodi {tapahtumamääritelmät} {
    set code {
      foreach {tapahtuma vars code} ${tapahtumamääritelmät} {
        proc $tapahtuma $vars $code
      }
    }

    if {[ catch { eval $code } ]} {
      return false
    }

   return true
  }

  #
  # tapahtumia, joista kertominen käyttäjälle voi olla liian vaikeasti
  # ymmärrettävää (aloittelijavaiheessa)
  #

  komento alustus {getent_robotin_username oma_uid robotti_ok} {
    set virheviesti [expr { $robotti_ok ? "" : " (VIRHE)" }]

    if {$getent_robotin_username eq ""} {
      nimi "???"
      return
    }

    aseta kentät [split $getent_robotin_username :]
    aseta nimi [lindex ${kentät} 4]
    if {$nimi ne ""} {
      nimi "${nimi}${virheviesti}"
    }

    aseta robotin_uid [lindex ${kentät} 2]
    if {$oma_uid eq $robotin_uid} {
      värit "ff0000 dd0000"
    }
  }

  komento energiataso {energia} {
    muista ENERGIA
    aseta ENERGIA $energia
  }

  komento koordinaatit {x y suunta} {
    muista X Y SUUNTA
    aseta X $x
    aseta Y $y
    aseta SUUNTA $suunta

    älä viestitä "koordinaatit on: $X $Y $SUUNTA"
  }

  komento omia.tietoja {peliaika nopeus tykinsuunta} {
    muista PELIAIKA NOPEUS TYKINSUUNTA
    aseta PELIAIKA $peliaika
    aseta NOPEUS $nopeus
    aseta TYKINSUUNTA $tykinsuunta
  }

  komento robotteja.jäljellä {montako} {
    muista ROBOTTEJA_ON $montako
  }

  komento toisen.robon.tietoja {energiataso onko_kaveri} {
    älä viestitä "Saatiin toisen robon tiedot, energiataso ${energiataso}"
  }

  komento kuolin {} {
    älä viestitä "Nousen vielä haudasta!"
    älä viestitä "Oi joi voi, kuolin!"
  }

  komento lopetus     {args} {}
  komento nimesi      {args} {}
  komento peli.loppuu {} {}
  komento peli.optio  {mikä mitä} {}
  komento varoitus    {args} {}
  komento värisi      {args} {}

  #
  # toimenpiteet
  #

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
    käännä robottia $paljonko
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
      0 { tutkassa.robotti ${etäisyys} }
      1 { tutkassa.ammus   ${etäisyys} }
      2 { tutkassa.seinä   ${etäisyys} }
      3 { tutkassa.nami    ${etäisyys} }
      4 { tutkassa.miina   ${etäisyys} }
    }
  }

  komento törmäys {mikä suunta} {
    set pi 3.14159265359
    set double_pi [expr { 2 * $pi }]
    set suunta_mod [expr { fmod($suunta, $double_pi) }]

    if {$suunta_mod < 0} {
      aseta suunta_mod [expr { $suunta_mod + $double_pi }]
    }

    aseta suunta_sanana [
      expr {
	([expr { 0.25 * $pi }] <= $suunta_mod
	   && $suunta_mod < [expr { 0.75 * $pi }])
	  ? "vasemmalla"
	  :
	([expr { 0.75 * $pi }] <= $suunta_mod
	   && $suunta_mod < [expr { 1.25 * $pi }])
	  ? "takana"
	  :
	([expr { 1.25 * $pi }] <= $suunta_mod
	   && $suunta_mod < [expr { 1.75 * $pi }])
	  ? "oikealla"
	  :
	"edessä"
      }
    ]

    switch -- ${mikä} {
      0 { törmäsin.robottiin $suunta_sanana }
      1 { törmäsin.ammukseen $suunta_sanana }
      2 { törmäsin.seinään   $suunta_sanana }
      3 { törmäsin.namiin    $suunta_sanana }
      4 { törmäsin.miinaan   $suunta_sanana }
    }
  }

  komento viestitä {sisältö} {
    puts "Print ${sisältö}"
  }
}

proc lue_tiedosto {polku} {
  set fd [open $polku]
  set robotdata [read $fd]
  close $fd
  return $robotdata
}

proc dispatch_event {event_type args} {
  global robot_ok
  global robotinterp
  global robotin_username

  set events {
    Collision       törmäys
    Coordinates     koordinaatit
    Dead            kuolin
    Energy          energiataso
    ExitRobot       lopetus
    GameFinishes    peli.loppuu
    GameOption      peli.optio
    GameStarts      alku
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
    return
  }

  set cmd [dict get $events $event_type]

  if {$cmd eq "alustus" && [lindex $args 0]} {
    # do this here because can't do exec in safe interpreter
    set getent  [exec getent passwd $robotin_username]
    set oma_uid [exec id -u]
    set call_args [list $getent $oma_uid $robot_ok]
  } else {
    set call_args $args
  }

  robotinterp eval $cmd $call_args
}

proc readevent {chan} {
  if {[eof $chan]} {
    exit 0
  }

  set eventline [gets $chan]

  set event [list]
  foreach _ [split $eventline] { if {$_ ne ""} { lappend event $_ } }

  if {[llength $event] > 0} {
    catch { dispatch_event {*}$event }
  }
}

set robot_ok [
  robotinterp eval robottikoodi [list [lue_tiedosto $robottitiedosto]]
]

fileevent stdin readable [list readevent stdin]

vwait forever
