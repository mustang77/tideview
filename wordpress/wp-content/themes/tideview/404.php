<?php
/**
 * 404 page.
 *
 * @package TideView
 */

get_header();
?>

<div class="tv-empty">
	<h1><?php esc_html_e( 'Lost at sea', 'tideview' ); ?></h1>
	<p><?php esc_html_e( 'That page drifted away with the tide. Try searching, or head back to shore.', 'tideview' ); ?></p>
	<?php get_search_form(); ?>
	<p style="margin-top: 24px;">
		<a class="tv-btn tv-btn-primary" href="<?php echo esc_url( home_url( '/' ) ); ?>"><?php esc_html_e( 'Back to home', 'tideview' ); ?></a>
	</p>
</div>

<?php
get_footer();
