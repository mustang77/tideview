<?php
/**
 * Post card used in blog grids.
 *
 * @package TideView
 */
?>
<article <?php post_class( 'tv-post-card' ); ?>>
	<a class="tv-post-thumb" href="<?php the_permalink(); ?>" aria-hidden="true" tabindex="-1">
		<?php the_post_thumbnail( 'medium_large' ); ?>
	</a>
	<div class="tv-post-body">
		<span class="tv-post-meta"><?php echo esc_html( get_the_date() ); ?></span>
		<h3><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
		<p><?php echo esc_html( get_the_excerpt() ); ?></p>
	</div>
</article>
