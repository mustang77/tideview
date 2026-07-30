<?php
/**
 * Blog index / archive fallback.
 *
 * @package TideView
 */

get_header();
?>

<div class="tv-archive-title">
	<span class="tv-eyebrow"><?php esc_html_e( 'Blog', 'tideview' ); ?></span>
	<h1>
		<?php
		if ( is_home() && ! is_front_page() ) {
			single_post_title();
		} elseif ( is_archive() ) {
			the_archive_title();
		} elseif ( is_search() ) {
			/* translators: %s: search query. */
			printf( esc_html__( 'Results for “%s”', 'tideview' ), esc_html( get_search_query() ) );
		} else {
			esc_html_e( 'Latest posts', 'tideview' );
		}
		?>
	</h1>
</div>

<section class="tv-section">
	<div class="tv-container">
		<?php if ( have_posts() ) : ?>
			<div class="tv-posts">
				<?php
				while ( have_posts() ) :
					the_post();
					get_template_part( 'template-parts/content', 'card' );
				endwhile;
				?>
			</div>
			<nav class="tv-pagination" aria-label="<?php esc_attr_e( 'Posts navigation', 'tideview' ); ?>">
				<?php echo wp_kses_post( paginate_links( array( 'type' => 'plain' ) ) ); ?>
			</nav>
		<?php else : ?>
			<div class="tv-empty">
				<h1><?php esc_html_e( 'Nothing here yet', 'tideview' ); ?></h1>
				<p><?php esc_html_e( 'No posts matched. Try a different search.', 'tideview' ); ?></p>
				<?php get_search_form(); ?>
			</div>
		<?php endif; ?>
	</div>
</section>

<?php
get_footer();
