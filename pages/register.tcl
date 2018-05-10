::nx::mongo::db connect -db "tutorial"

# this is the page where new users can register
# it checks whether a username already exists and if so displays an error message

set username   [ns_quotehtml [ns_queryget username]]
set password   [ns_quotehtml [ns_queryget password]]

# build a register page, displays an error message if there is one
# the error message can be an html element

namespace eval ::businessInsider {

proc buildRegisterPage {errMsg} {
	return [subst {
	[defaultLibraries]
	<body>
	<div class='container-fluid' style='margin:auto;width:40%;'>
	<h1>Please register!</h1>
	<form method='post' action='register.tcl'>
	  <div class='form-group'>
	    <label for='username'>Username</label>
	    <input type='text' class='form-control' name='username' id='username' placeholder='Enter username' required>
	  </div>
	  <div class='form-group'>
	    <label for='password'>Password</label>
	    <input type='password' class='form-control' name='password' id='password' 
		placeholder='Enter password' required aria-describedby='pwlHelp'>
	    <small id='pwHelp' class='form-text text-muted'>Must be at least 5 characters long</small>
	  </div>
	 $errMsg
	  <button type='submit' class='btn btn-primary'>Register</button>
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
	ns_return 200 text/html [buildRegisterPage ""]
} else {
	# check if user exists
	set user [User find first -cond [subst {username = "$::username"}]]
    	if {$user ne ""} {
		ns_return 200 text/html [buildRegisterPage [buildErrorDiv "Registration failed! User already exists."]]
	} elseif {[string length $password] < 5} {
		ns_return 200 text/html [buildRegisterPage [buildErrorDiv "Registration failed! Password too short."]]
	} else {
		set newUser [User new -username $::username -password $::password]
		$newUser save
		ns_return 200 text/html [subst {
			[defaultLibraries]
			<body>
			<div class='container-fluid' style='margin:auto;width:40%;'>
			<h1>Registration successfull!</h1><br>
			<h2>Welcome $::username to our forum!</h2><br>
			<a class='btn btn-primary' href='login.tcl' role='button'>Forum</a>
			</div>
			</body>
			</html>
		}]
 	}
}
}
