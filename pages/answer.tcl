::nx::mongo::db connect -db "tutorial"

# here the user can post an answer to a question
# a user should be logged in to answer

set questionId [ns_quotehtml [ns_queryget questionid]]
set answer     [ns_quotehtml [ns_queryget answer]]

namespace eval ::businessInsider {

# display error if credentials are wrong 
set user [isLoggedin]
if {$user eq ""} {
  ns_return 200 text/html [pleaseLogin]
} else {
  if {$::answer eq ""} {
  # find the question object
  set question [Question find first -cond [subst {_id = "$::questionId"}]]
  # use template for display
  ns_return 200 text/html [subst {
[defaultLibraries]
<body>
<div class='container-fluid'>
<h1>Post a new answer</h1>
<h2>Question:</h2>
[$question template eval]
<hr>
<form method='post' action='answer.tcl'>
  <div class='form-group'>
    <input type='hidden' name='questionid' value='$::questionId'> 
    <label for='answer'>Your answer</label>
    <input type='text' class='form-control' name='answer' id='answer' placeholder='Enter answer' required>
  </div>
  <button type='submit' class='btn btn-primary'>Submit</button>
  <a href='index.tcl' class='btn btn-primary' role='button'>Back</a>
</form>
</div>
</body>
</html>
  }]
  # if there is an answer
  } else {
    # find the question object
    set question [Question find first -cond [subst {_id = "$::questionId"}]]
    # make a new answer and add it to the question
    set a [Answer new \
		-author $user \
		-answer $::answer \
		-ts [clock format [clock seconds] -format "%d-%b-%y %H:%M"]]
    $a save
    $question answers add $a
    $question save 
    ns_returnredirect "answer.tcl?questionid=$::questionId"
  }
}

}


