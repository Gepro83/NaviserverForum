::nx::mongo::db connect -db "tutorial"

#
# This is a page for posting a new question 
# the user should be logged in to get here
# userdetails are transmitted as a POST message

set title	[ns_quotehtml [ns_queryget title]]
set description [ns_quotehtml [ns_queryget description]]
set tags	[ns_quotehtml [ns_queryget tags]]

namespace eval ::businessInsider {

# display error if credentials are wrong 
set user [isLoggedin]
if {$user eq ""} {
	ns_return 200 text/html [pleaseLogin]
} else {

# display a form to post a new question
if {$description eq "" || $description eq ""} {
	ns_return 200 text/html [subst {
[defaultLibraries]
<body>
<div class='container-fluid'>
<h1>[$user username get] post a new question</h1>
<form method='post' action='new-question.tcl'>
  <div class='form-group'>
    <label for='title'>The title of your question</label>
    <input type='text' class='form-control' name='title' id='title' placeholder='Enter title' required>
    </div>
  <div class='form-group'>
    <label for='description'>Your question</label>
    <textarea id='description' class='form-control' name='description' 
	cols='35' rows='4' placeholder='Place your question' required></textarea>
  </div>
  <div class='form-group'>
    <label for='tags'>Tags</label>
    <input type='text' class='form-control' name='tags' id='tags' aria-describedby='taghelp' placeholder='Your tags'>
    <small id='taghelp' class='form-text text-muted'>Separate tags with whitespaces, e.g. "finance taxes" will result in two tags.</small>
  </div>
  <button type='submit' class='btn btn-primary'>Submit</button>
</form>
</div>
</body>
</html>
}]
} else {
	# the user posted a question
	# split up tags at whitespaces
	set tagsList [regexp -all -inline {\S+} $tags]
	# create a new question object and save it
	set q [Question new \
		   -title $title \
		   -author $user \
		   -description $description \
		   -tags $tagsList \
		   -ts [clock format [clock seconds] -format "%d-%b-%y %H:%M"]]
	$q save
	ns_returnredirect index.tcl
}
}
}

