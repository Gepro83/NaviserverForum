package require nx::mongo

#
# Make sure to load oo-templating before this file.
#
if {[info command ::compile_template] eq ""} {source [file dirname [info script]]/oo-templating.tcl}

######################################################################
# Create the application classes based on the "Business Insider" data
# model. See e.g.
# http://www.slideshare.net/mongodb/nosql-the-shift-to-a-nonrelational-world
#
# The classes are kept in the namespace "bi" for better locality.  The
# created classes have a "bi::" prefix; they can be either adressed by
# their fully qualified names or inside a "namespace eval ::bi {...}"
# statement.
#
# This file contains as well the navigation structures for the "bi"
# application and the necessary templates for viewing with and without
# edit-controls.

::nx::mongo::db connect -db "tutorial"
#::nx::mongo::db drop collection questions
#::nx::mongo::db drop collection answers

#? {::nx::mongo::db collection tutorial.persons} "mongoc_collection_t:0"

namespace eval businessInsider {

# Changed it so that an answer does not contain any more answers
# so that there is no infinite number of nested answers anymore
# also added a timestamp and upvoting
  nx::mongo::Class create Answer {
    # keep a list of user that have upvoted this answer
    :property -accessor public {upvoteUsers:reference,type=::businessInsider::User,0..n {}}
    :property -accessor public author:reference,type=::businessInsider::User,required
    :property -accessor public answer:required
    :property -accessor public ts:required
    :property -accessor public {upvotes:integer 0}
    # upvotes an answer, each user can only upvote once per answer
    :public method upvote {user:object,type=::businessInsider::User,required} {
        if {[: -local canUpvote $user]} {
		lappend :upvoteUsers $user
		incr :upvotes
	}
    }
    # check whether a user is allowed to upvote this answer
    :public method canUpvote {user:object,type=::businessInsider::User,required} {
    	foreach currUser ${:upvoteUsers} {
		if {[$currUser cget -_id] eq [$user cget -_id]} {
			return false
		}
	}
	return true
    }
  }
   

  nx::mongo::Class create Question {
    :index tags
    :property -accessor public title:required
    :property -accessor public author:reference,type=::businessInsider::User,required
    :property -accessor public description:required
    :property -accessor public ts:required
    :property -accessor public -incremental {answers:reference,type=::businessInsider::Answer,0..n {}}
    :property -accessor public -incremental {tags:0..n ""}
    # keep the rating, the number of times the posting was rated 
    # and a list of users that rated the question
    :property -accessor public {rateUsers:reference,type=::businessInsider::User,0..n {}}
    :property -accessor public {rating:double 0.0}
    :property -accessor public {numRates:integer 0}
    # a user can rate a question with a rating between 1 and 5
    # the total rating of a question is the acerage rating 
    :public method rate {
	user:object,type=::businessInsider::User,required
	rating:integer,required
	} {
	if {[: -local canRate $user]} {
		if {$rating > 5} { set rating 5 }
		if {$rating < 1} { set rating 1 }
		set totRating [expr {[:rating get] * [:numRates get] + $rating}]
		incr :numRates
		:rating set [expr {$totRating / ${:numRates}}]
		lappend :rateUsers $user
	}
    }
    # check whether a user is allowed to rate this question
    :public method canRate {user:object,type=User,required} {
    	foreach currUser ${:rateUsers} {
		if {[$currUser cget -_id] eq [$user cget -_id]} {
			return false
		}
	}
	return true
    }
  }

  nx::mongo::Class create User {
    :index username
    :property -accessor public username:required
    :property -accessor public password:required
  }
  
  

  #
  # Helper procs for navigation and introspection
  #

  proc classes {} {
    set classInfo "MongoDB Classes:\n"
    foreach cl [lsort [nx::mongo::Class info instances]] {
      append classInfo [subst {
	class $cl
	  variables:       [$cl pretty_variables]
	instances in db: [$cl count]
	}]
    }
    return $classInfo
  }

  proc defaultLibraries {} {
	return {
<html>
<head>
<title>Business Insider Question and Answer</title>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0-beta.3/css/bootstrap.min.css" integrity="sha384-Zug+QiDoJOrZ5t4lssLdxGhVrurbmBWopoEl+M6BdEfwnCJZtKxi1KgxUyJq13dy" crossorigin="anonymous">
<link rel='stylesheet' href='style.css'>
<script src="https://code.jquery.com/jquery-3.2.1.slim.min.js" integrity="sha384-KJ3o2DKtIkvYIK3UENzmM7KCkRr/rE9/Qpg6aAZGJwFDMVNA/GpGFF93hXpG5KkN" crossorigin="anonymous"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.12.9/umd/popper.min.js" integrity="sha384-ApNbgh9B+Y1QKtv3Rn7W3mgPxhU9K/ScQsAP7hUibX39j7fakFPskvXusvfa0b4Q" crossorigin="anonymous"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0-beta.3/js/bootstrap.min.js" integrity="sha384-a5N7Y/aK3qNeh15eJKGWxsqtnX/wWdSZSKp+81YjTmS15nvnvxKHuzaWwXHDli+4" crossorigin="anonymous"></script>
</head>
	}  
  }

  # makes a page that asks the user to login
  proc pleaseLogin {} {
	return [subst {
	[defaultLibraries]
        <body>
	<div class='container-fluid' style='margin:auto;width:40%;'>
	<h1>Please login first!</h1><br>
	<a class='btn btn-primary' style='margin-left:25%' href='login.tcl' role='button'>Login</a>
	</div>
        </body>
        </html>
	}]
  }

  # Cookie functions - central point of control for cookie management
  
  # creates a cookie containing username and password
  proc login {username password} {
  	ns_setcookie -replace true userinfo [list $username $password]
  }

  # check whether a cookie containing the userdata is set and whether the login data is valid
  # returns the user object of the logged in user or an empty string if login data is invalid 
  proc isLoggedin {} {
  	set userinfo [ns_getcookie userinfo [list "" ""]]
	# check whether login data is valid
	set username [lindex $userinfo 0]
	set password [lindex $userinfo 1]
	set user [User find first -cond [subst {username = "$username"}]]
	if {$user eq ""} {
		return ""
	} else {
		if {[$user password get] eq $password} {
			return $user
		} else {
			return ""
		}
	}
  }

  # sets a cookie for userinfo
  proc setCookie {username password} {
	ns_setcookie -replace true userinfo [list $username $password]
  }

  # deletes the cookie for userinfo
  proc delCookie {} {
	ns_deletecookie userinfo
  }

  # find the question object to a given answer object
  proc findQuestion {answer} {
	# this could probably be improved with a direct query to mongodb
	set questions [Question find all]
    	set question ""
    	foreach currQuestion $questions {
    		foreach currAnswer [$currQuestion answers get] {
			if {[$currAnswer cget -_id] eq [$answer cget -_id]} {
				set question $currQuestion
				break
			}
		}
		if {$question ne ""} {
			return $question
		}
    	}
	return ""
  }
 
  # templates

  Question template set {
    <% set ::_id [set :_id] %> 
    @:title@ - <b><%= [${:author} username get] %></b> <span class='timestamp'>@:ts@</span>
    <hr>
    @:description@
    <hr>
    <%
	# sort answers by upvotes
	proc compare {a1 a2} {
		if {[$a1 upvotes get] > [$a2 upvotes get]} {
			return -1
		} else {
			return 1
		}
	}
	if {[llength ${:answers}] > 0} {  
		set :answers [lsort -command compare ${:answers}]
	}
    %>
    <ul class='list-group'><FOREACH var='c' in=':answers' type='list'>
	<li class='list-group-item'>@c;obj@</li>
    </FOREACH></ul>
    tags: @:tags@<br>
    rating: @:rating@<br>
    <%  set ::ratelink ""
    	set user [::businessInsider::isLoggedin]
	# only logged in users can rate
	if {$user ne ""} {
		# users can rate only once
		if {[: -local canRate $user]} {
			set ::ratelink [subst {
    <div class='dropdown'>
    <button class='btn btn-secondary dropdown-toggle' type='button' id='rate' data-toggle='dropdown' 
	aria-haspopup='true' aria-expanded='false'>Rate
    </button>
    <div class='dropdown-menu' aria-labelledby='rate'>
    <a class='dropdown-item' href='rate.tcl?questionid=${:_id}&rating=1'>1</a>
    <a class='dropdown-item' href='rate.tcl?questionid=${:_id}&rating=2'>2</a>
    <a class='dropdown-item' href='rate.tcl?questionid=${:_id}&rating=3'>3</a>
    <a class='dropdown-item' href='rate.tcl?questionid=${:_id}&rating=4'>4</a>
    <a class='dropdown-item' href='rate.tcl?questionid=${:_id}&rating=5'>5</a>
    </div>
    </div>}]
		}
	}
      %>
    <%= [set ::ratelink] %>

    
  }
    
  Answer template set {
    @:answer@ - <b><%= [${:author} username get] %></b> - 
    <span class='timestamp'>@:ts@</span> - Upvotes: @:upvotes@ 
    <%  set ::upvotelink ""
	set user [::businessInsider::isLoggedin]
	# only logged in users can upvote
	if {$user ne ""} {
		# users can upvote only once
		if {[: -local canUpvote $user]} {
			set ::upvotelink "<a title='upvote' class='btn btn-secondary btn-sm' role='button'
				href='upvote.tcl?answerid=${:_id}'>UP</a>"
		}
	}
      %>
    <%= [set ::upvotelink] %>
  }


}
