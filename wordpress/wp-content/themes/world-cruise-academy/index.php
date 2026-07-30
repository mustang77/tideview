<?php
/**
 * Blog index / archive fallback.
 *
 * @package WorldCruiseAcademy
 */

get_header();
?>

<div class="wca-archive-title">
	<span class="wca-eyebrow"><?php esc_html_e( 'News', 'worldcruiseacademy' ); ?></span>
	<h1>
		<?php
		if ( is_home() && ! is_front_page() ) {
			single_post_title();
		} elseif ( is_archive() ) {
			the_archive_title();
		} elseif ( is_search() ) {
			/* translators: %s: search query. */
			printf( esc_html__( 'Results for “%s”', 'worldcruiseacademy' ), esc_html( get_search_query() ) );
		} else {
			esc_html_e( 'Latest news', 'worldcruiseacademy' );
		}
		?>
	</h1>
</div>

<section class="wca-section">
	<div class="wca-container">
		<?php if ( have_posts() ) : ?>
			<div class="wca-posts">
				<?php
				while ( have_posts() ) :
					the_post();
					get_template_part( 'template-parts/content', 'card' );
				endwhile;
				?>
			</div>
			<nav class="wca-pagination" aria-label="<?php esc_attr_e( 'Posts navigation', 'worldcruiseacademy' ); ?>">
				<?php echo wp_kses_post( paginate_links( array( 'type' => 'plain' ) ) ); ?>
			</nav>
		<?php else : ?>
			<div class="wca-empty">
				<h1><?php esc_html_e( 'Nothing here yet', 'worldcruiseacademy' ); ?></h1>
				<p><?php esc_html_e( 'No posts matched. Try a different search.', 'worldcruiseacademy' ); ?></p>
				<?php get_search_form(); ?>
			</div>
		<?php endif; ?>
	</div>
</section>

<?php
get_footer();
