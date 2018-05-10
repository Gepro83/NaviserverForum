#ns_log notice "=== source oo-templating [info script]"
package require nsf

namespace eval template {

  nsf::proc compile {
    {-filter ""} 
    {-localize_template _} 
    {-localize_value ::lang::util::localize} 
    {-formats ""} 
    template
  } {
    # Escape "[", "]" and "\"
    regsub -all {(\[|\]|\\)} $template {\\\1} template

    # scalar with filter 
    regsub -all {@([:a-zA-Z0-9_]+)@} $template \
        "\[compile_var -filter {$filter} -localize {$localize_value} -formats {$formats} \\1\]" template
    # scalar with literal
    regsub -all {@([:a-zA-Z0-9_]+);literal@} $template "\[compile_var \\1\]" template
    # scalar as obj with template name
    regsub -all {@([:a-zA-Z0-9_]+);obj(;([a-zA-Z]*))?@} $template "\[compile_var_obj {\\3} \\1\]" template

    # composite accessor with filter
    regsub -all {@([:a-zA-Z0-9_]+).([:a-zA-Z0-9_]+)@} $template "\[compile_var2 -filter {$filter} -localize {$localize_value} \\1 \\2\]" template
    # composite accessor with literal
    regsub -all {@([:a-zA-Z0-9_]+).([:a-zA-Z0-9_]+);literal@} $template "\[compile_var2 \\1 \\2 \]" template

    if {$localize_template ne ""} {
      regsub -all {\#([a-zA-Z0-9_]+).([a-zA-Z0-9_]+)\#} $template "\[$localize_template \\1.\\2 \]" template
    }

    #regsub -all {{{([^<]+?)}}([&<\s]|$)} $template "\[::template::compile_include \"\\1\" \"\\2\" \]" template
    
    return [subst -novariable $template]
  }

  nsf::proc compile_var_ {{-filter ""} {-localize ""} {-formatfilter ""} value} {
    if {$formatfilter ne ""} {set value "\[$formatfilter $value\]"}
    if {$localize ne ""} {set value "\[$localize $value\]"}
    if {$filter   ne ""} {set value "\[$filter $value\]"}
    return "<%= $value %>"
  }

  nsf::proc compile_var_obj {{-filter ""} {-localize ""} template name} {
    if {$template eq ""} {set template default}
    compile_var_ -filter $filter -localize $localize "\[\${$name} template eval -name {$template}\]"
  }

  nsf::proc formatFilter {formats name} {
    if {[dict exists $formats $name]} {return [dict get $formats $name]}
    return ""
  }

  nsf::proc compile_var {{-filter ""} {-localize ""} {-formats ""} name} {
    compile_var_ -filter $filter -localize $localize -formatfilter [formatFilter $formats $name] \
        "\${$name}"
  }

  nsf::proc compile_var2 {{-filter ""} {-localize ""} {-formats ""} base name} {
    # TODO handle formats 
    compile_var_ -filter $filter -localize $localize -formatfilter [formatFilter $formats $base.$name] \
        "\[get_value2 ${base} ${name}\]"
  }

  #nsf::proc compile_include {content char} {
  #  return "<%= $content %>$char"
  #}

  nsf::proc get_value2 {base name} {
    upvar $base x
    #ns_log notice "exists var $base exists [info exists x]"
    ns_log notice "exists var $base exists [info exists x] base=$base, name=$name"
    if {![info exists x]} {return "NO SUCH VARIABLE $base"}
    #ns_log notice "exists var $base object <$x> [nsf::object::exists $x]"
    if {[nsf::object::exists $x]} {return [::nsf::var::set $x $name]}
    dict get $x $name
  }

  ns_adp_registerscript foreach /foreach ::template::tag-foreach
  ns_adp_registerscript exists /exists ::template::tag-exists
  ns_adp_registerscript wiki:includelet /wiki:includelet ::template::tag-wiki:includelet
  ns_adp_registerscript wiki:link /wiki:link ::template::tag-wiki:link


  #
  # sample usage <exists :matnr>@:matnr@</exists>
  #
  proc tag-exists {args} {
    #ns_log notice "tag-exists <$args>"
    lassign $args body set
    set __result ""
    set name [lindex [ns_set array $set] 0]
    #ns_log notice "tag-exists av_list [list info exists $name] // [uplevel [list info exists $name]]"
    if {[uplevel [list info exists $name]]} {
      set __result [uplevel [list :ns_adp_parse $body]]
      #set __result foo
    }
    return $__result
  }


  #we would like the content of a multiple be a 
  # ordered composite
  # ns_set
  # dict
  # multirow

  proc tag-foreach {body set} {
    set av_list [ns_set array $set]
    array set __options {type list} ;# default
    #ns_log notice "options = [ns_set array $set]"

    array set __options [ns_set array $set]
    if {![info exists __options(var)]} {return "ERROR: no variable specified for MULTIPLE"}
    set __result ""
    switch -- $__options(type) {
      list {
	upvar $__options(in) __source
	if {[info exists __source]} {
	  foreach $__options(var) $__source {append __result [ns_adp_parse $body]}
	}
      }
      ns_set {
	upvar $__options(in) __source 
        for {set __i 0} {$__i < [ns_set size $__source]} {incr __i} {
          set [ns_set key $__source $__i] [ns_set value $__source $__i]
          lassign [list [ns_set key $__source $__i] [ns_set value $__source $__i]] {*}$__options(var) 
          append __result [ns_adp_parse $body]
        }
      }
      ordered_composite {
	upvar $__options(in) __source 
	set __result "$__options(in) [info exists __source] $__source b=$body"
	foreach $__options(var) [$__source children] {append __result [ns_adp_parse $body]}
      }
    }
    return $__result
  }

  #
  # Sample usage: <wiki:includelet>NewsItem -max 7</wiki:includelet>
  #
  proc tag-wiki:includelet {body set} {
    ns_log notice "tag-wiki:includelet <$body> $set"
    set words [split $body " "]
    set cmd [lindex $words 0]
    if {[nsf::is object $cmd] && [$cmd info object method exists includelet]} {
      return [$cmd includelet {*}[lrange $words 1 end]]
    }
    return ""
  }

  #
  # Sample usage: <wiki:link>NewsItem -max 7</wiki:link>
  #
  proc tag-wiki:link {body set} {
    #ns_log notice "tag-wiki:link <$body> $set"
    set label [ns_set get $set title $body]
    if {[string match "*://*" $body]} {
      set classInfo "class='external'"
    } elseif {[string match img:* $body]} {
      regexp {img:(.*)$} $body _ src
      set styles ""
      foreach {opt value} [ns_set get $set options] {
        if {$opt eq "-float"} {append styles "[string range $opt 1 end]: $value\;"}
      }
      if {$styles ne ""} {set styles "style='$styles'"}
      return "<img class='image' title='$label' alt='$src' src='$src' $styles/>"
      set classInfo "img"
    } else {
      set classInfo ""
    }
    return "<a $classInfo href='$body'>$label</a>"
  }
}

::nsf::method::alias nx::Object ns_adp_parse ::ns_adp_parse 

nx::Object public method "template set" {{-name default} {-formats ""} {-include ""} string} {
  set :__template_head($name) ""
  foreach file $include {
    if {[string match *.js $file]} {
      append :__template_head($name) [subst {<script type="text/javascript" src="$file" language="javascript"></script>}] \n
    } elseif {[string match *.css $file]} {
      append :__template_head($name) [subst {<link rel="stylesheet" href="$file" type="text/css" media="all">}] \n
    }
  }
  set :__template($name) [template::compile \
                              -localize_value "" \
                              -filter ns_quotehtml \
                              -formats $formats \
                              $string]
}

nx::Object public method "template get" {{-name "default"}} {
  if {[info exists :__template($name)]} {
    append ::__template__head [set :__template_head($name)] \n
    return [set :__template($name)]
  }
  return ""
}

nx::Object public method "template iterate" {method {-name "default"}} {
  set v [:template $method -name $name]
  if {$v ne ""} {return $v}
  foreach cl [:info precedence] {
    set v [$cl template $method -name $name]
    if {$v ne ""} {break}
  }
  return $v
}

nx::Object public method "template eval" {{-name "default"} {template ""}} {
  if {$template ne ""} {
    return [:ns_adp_parse [template::compile -localize_value "" $template]]
  }
  set template [:template iterate get -name $name]
  return [:ns_adp_parse $template]
}

::Serializer exportMethods {
  ::nx::Object method "ns_adp_parse"
  ::nx::Object method "template eval"
  ::nx::Object method "template get"
  ::nx::Object method "template iterate"
  ::nx::Object method "template set"
}

return
##############################
proc f {value} {return /$value/}
::nsf::method::alias nx::Object ns_adp_parse ::ns_adp_parse 
nx::Object create o {
  set :x "this is x"; 
  set :y 2
  set :oc [::xowiki::Object instantiate_objects -sql {select * from acs_objects order by 1 limit 10}]
}
nx::Object create o2 {
  set :x "this is o2"; 
  set :y 4711
}

set c(0) {
  x = <%=$x%>
  :x = <%= [f ${:x}] %>
}
set t(1) {<% set somelist {1 a 2 b 3 c} %>
  #xowiki.title#
  x = @:x@          ... instance variable 
  y = @:y;literal@ .... instance variable
  <FOREACH var='a b' in='somelist' type='list'>key = @a@, value = @b@
  </FOREACH>
}

set t(1) {<% set headers [ns_conn headers] %>
  #xowiki.title#
  x = @:x@          ... instance variable 
  y = @:y;literal@ .... instance variable
  <FOREACH var='tag value' in='headers' type='ns_set'>tag = @tag@, value = @value@
  </FOREACH>
}

set t(1) {<% set o2 ::o2; set x 456; set d [dict create name gustaf sex male] %>
  #xowiki.title#
  x = @x@  local variable
  y = @:y;literal@ .... instance variable of current object
  o2.x = @o2.x@ .... attrib x of object o2
  name @d.name@ sex @d.sex@
  <FOREACH var='o' in=':oc' type='ordered_composite'>object_id = @o.object_id@ @o.title@ @o.object_type@
  </FOREACH>
}


#o ns_adp_parse $c(1)

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 2
#    indent-tabs-mode: nil
# End:
