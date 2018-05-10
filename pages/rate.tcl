# this page just updates the rating of a question and then redirects back to the answer page
# each user can rate only once per question

set questionId [ns_quotehtml [ns_queryget questionid]]
set rating     [ns_quotehtml [ns_queryget rating]]

namespace eval ::businessInsider {

# display error if credentials are wrong 
set user [isLoggedin]
if {$user eq ""} {
	ns_return 200 text/html [pleaseLogin]
} else {
	# find the question object
	set question [Question find first -cond [subst {_id = "$::questionId"}]]
    	if {$question eq ""} {
		ns_returnerror 400 "invalid question"
	} else {
		# rate the question and redirect to the answer page
		if {![$question canRate $user]} {
			ns_returnerror 400 "[$user username get] cannot rate this question anymore"
		} else {
			$question rate $user $rating
			$question save
			ns_returnredirect "answer.tcl?questionid=$questionId"
		}
	}
}

}


