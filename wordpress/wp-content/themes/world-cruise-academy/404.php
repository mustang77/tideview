<?php
/**
 * 404 page.
 *
 * @package WorldCruiseAcademy
 */

get_header();
?>

<div class="wca-empty">
	<h1><?php esc_html_e( 'Lost at sea', 'worldcruiseacademy' ); ?></h1>
	<p><?php esc_html_e( 'That page has sailed. Try searching, or head back to port.', 'worldcruiseacademy' ); ?></p>
	<?php get_search_form(); ?>
	<p style="margin-top: 24px;">
		<a class="wca-btn wca-btn-primary" href="<?php echo esc_url( home_url( '/' ) ); ?>"><?php esc_html_e( 'Back to home', 'worldcruiseacademy' ); ?></a>
	</p>
</div>

<?php
get_footer();
