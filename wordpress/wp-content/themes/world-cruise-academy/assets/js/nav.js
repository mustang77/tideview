( function () {
	var toggle = document.querySelector( '.wca-nav-toggle' );
	var nav = document.getElementById( 'wca-primary-nav' );

	if ( ! toggle || ! nav ) {
		return;
	}

	toggle.addEventListener( 'click', function () {
		var open = nav.classList.toggle( 'is-open' );
		toggle.setAttribute( 'aria-expanded', open ? 'true' : 'false' );
		toggle.classList.toggle( 'is-open', open );
	} );

	// Close the menu after tapping a link (useful for same-page anchors).
	nav.addEventListener( 'click', function ( e ) {
		if ( e.target.closest( 'a' ) ) {
			nav.classList.remove( 'is-open' );
			toggle.classList.remove( 'is-open' );
			toggle.setAttribute( 'aria-expanded', 'false' );
		}
	} );
} )();
