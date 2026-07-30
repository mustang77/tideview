<?php
/**
 * Search form.
 *
 * @package TideView
 */
?>
<form role="search" method="get" class="tv-search-form" action="<?php echo esc_url( home_url( '/' ) ); ?>">
	<label class="screen-reader-text" for="tv-search-field"><?php esc_html_e( 'Search for:', 'tideview' ); ?></label>
	<input type="search" id="tv-search-field" name="s" value="<?php echo get_search_query(); ?>" placeholder="<?php esc_attr_e( 'Search…', 'tideview' ); ?>">
	<button type="submit" class="tv-btn tv-btn-primary"><?php esc_html_e( 'Search', 'tideview' ); ?></button>
</form>
