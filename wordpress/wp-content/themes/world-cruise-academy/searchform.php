<?php
/**
 * Search form.
 *
 * @package WorldCruiseAcademy
 */
?>
<form role="search" method="get" class="wca-search-form" action="<?php echo esc_url( home_url( '/' ) ); ?>">
	<label class="screen-reader-text" for="wca-search-field"><?php esc_html_e( 'Search for:', 'worldcruiseacademy' ); ?></label>
	<input type="search" id="wca-search-field" name="s" value="<?php echo get_search_query(); ?>" placeholder="<?php esc_attr_e( 'Search…', 'worldcruiseacademy' ); ?>">
	<button type="submit" class="wca-btn wca-btn-primary"><?php esc_html_e( 'Search', 'worldcruiseacademy' ); ?></button>
</form>
