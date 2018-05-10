::nx::mongo::db connect -db "tutorial"


#the html that will contain the list of questions
set questionsHtml ""
#the standard navigation bar without being logged in
set navbar "<a class='btn btn-primary' role='button' href='login.tcl'>Login</a>
	    <a class='btn btn-primary' role='button' href='register.tcl'>Register</a>"
# currently active tags are saved in cookie
set activetags [ns_getcookie tags ""]
# tag was added
set addtag [ns_quotehtml [ns_queryget addtag]]
if {$addtag ne ""} {
	lappend activetags $addtag
	# update tagcookie
	ns_setcookie -replace true tags $activetags
}
# tag was removed
set removetag [ns_quotehtml [ns_queryget rmtag]]
if {$removetag ne ""} {
	set idx [lsearch $activetags $removetag]
	set activetags [lreplace $activetags $idx $idx]
	# update tagcookie
	ns_setcookie -replace true tags $activetags
}
# a bar for active tags
set tagbar "Tags: "
foreach tag $activetags {
	append tagbar "<a class='tag' href='index.tcl?rmtag=$tag'>$tag</a>"
}

namespace eval ::businessInsider {
  if {[Question count] > 0} {

    set filteredquestions [Question find all -orderby ts]
    # if tags are active only show questions that have at least one matching tag
    if {$::activetags ne ""} {
	foreach question $filteredquestions {
		set remove true
		foreach tag $activetags {
			if {$tag in [$question tags get]} {
				set remove false
				break
			}
		}
		if {$remove} {
			set idx [lsearch $filteredquestions $question]
			set filteredquestions [lreplace $filteredquestions $idx $idx]
		}
	}
    }
    set result [nx::Object new {set :questions $::businessInsider::filteredquestions}]

    # in the main page only the title, author and timestamp of a question is shown
    $result template set {
	<div class='list-group'><FOREACH var='q' in=':questions' type='list'>
       	 <a class='list-group-item list-group-item-action' href='answer.tcl?questionid=@q._id@'>
	<table style='width:100%;'>
	<tr>
	<td>
	<div align="left">
	@q.title@ - <b><%= [[$q author get] username get] %></b>  <span class='timestamp'>@q.ts@</span>
	</div>
	</td>
	<td> 
	<div align="right">
	<% 	set tagspans ""
		foreach tag [$q tags get] {
			append tagspans "<a href='index.tcl?addtag=$tag' class='tag'>$tag</a>"
		}
	%>
	<%= [set tagspans] %>
	</div>
	</td>
	</tr>
	</table>
    	 </a>
      	</FOREACH></div>
    }

    set ::questionsHtml [$result template eval]
    $result destroy
  }

  # once the user is logged in he can pose questions or log out
  set user [isLoggedin]
  if {$user ne ""} {
    set ::navbar [subst {
	<h3>Hi [$user username get] !</h3>
	<a class='btn btn-primary' role='button' href='new-question.tcl'>Post a question</a>
	<a class='btn btn-primary' role='button' href='logout.tcl'>Logout</a>
    }]
  }
}

ns_return 200 text/html [subst {
[businessInsider::defaultLibraries]
<body>
<div class='container-fluid'>
<div class='jumbotron'>
<h1 class='display-3'>Business Insider</h1>
<p class='lead'>This is a place where your questions are answered!</p>
</div>
$navbar
<hr>
<h1>Questions:</h1>
<hr>
$tagbar
<hr>
$questionsHtml
<hr>
<pre>
[businessInsider::classes]
Questions: [businessInsider::Question show -puts 0]
Answers: [businessInsider::Answer show -puts 0]
</div>
</pre>
</body>
</html>
}]
