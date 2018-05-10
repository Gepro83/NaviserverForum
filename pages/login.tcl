::nx::mongo::db connect -db "tutorial"

# this is the login page, it checks wether the user exists and
# the password matches and sets a cookie

set username   [ns_quotehtml [ns_queryget username]]
set password   [ns_quotehtml [ns_queryget password]]
set remember   [ns_quotehtml [ns_queryget remember]]

namespace eval ::businessInsider {

# build a login page, displays an error message if there is one
# the error message can be an html element
proc buildLoginPage {errMsg} {
	return [subst {
	[defaultLibraries]
	<body>
	<div class='container-fluid' style='margin:auto;width:40%;'>
	<h1>Welcome! Please login</h1>
	<form method='post' action='login.tcl'>
	  <div class='form-group'>
	    <label for='username'>Username</label>
	    <input type='text' class='form-control' name='username' id='username' 
		placeholder='Enter username' required>
	  </div>
	  <div class='form-group'>
	    <label for='password'>Password</label>
	    <input type='password' class='form-control' name='password' id='password' 
		placeholder='Enter password' required>
	 </div>
	  <div class="form-check">
	    <input type="checkbox" class="form-check-input" name='remember' id="remember">
	    <label class="form-check-label" for="remember">Remember me</label>
	  </div>
	  $errMsg
	  <button type='submit' class='btn btn-primary'>Login</button>
	</form>
	</div>
	</body>
	</html>
	}]
}

# creates a bootstrap alert div around the message
proc buildErrorDiv {message} {
	return [subst {
		<div class="alert alert-danger" role="alert">
		$message
		</div>
	}]
}

if {$::username eq "" || $::password eq ""} {
	ns_return 200 text/html [buildLoginPage ""]
} else {
	set currentUser [User find first -cond [subst {username = "$::username"}]]
	if {$currentUser eq ""} {
		ns_return 200 text/html \
			[buildLoginPage \
			[buildErrorDiv "Login failed! User $::username does not exist."]]
	} elseif {[$currentUser password get] ne $::password} {
		ns_return 200 text/html \
			[buildLoginPage \
			[buildErrorDiv "Login failed! Wrong password."]]
	} else {
		login $::username $::password
		ns_returnredirect index.tcl
	}
}
}
