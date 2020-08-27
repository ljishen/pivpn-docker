
auth.debug = 2
auth.backend = "plain"
auth.backend.plain.userfile = "/etc/lighttpd/.lighttpdpassword"

auth.require = ( "/" =>
	(
		"method" => "basic",
		"realm" => "Password protected area",
		"require" => "user=admin"
	)
)

