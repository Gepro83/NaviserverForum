# upvote an answer and redirect back to answer page
set answerId   [ns_quotehtml [ns_queryget answerid]]

namespace eval ::businessInsider {

# display error if credentials are wrong 
set user [isLoggedin]
if {$user eq ""} {
	ns_return 200 text/html [pleaseLogin]
} else {
    # find the answer object
    set answer [Answer find first -cond [subst {_id = "$::answerId"}]]
    if {$answer eq ""} {
    	ns_returnerror 400 "invalid answer"
    }
    $answer upvote $user
    $answer save
    # find the question object and redirect to answer page
    set question [findQuestion $answer]
    ns_returnredirect "answer.tcl?questionid=[$question cget -_id]"
}

}
