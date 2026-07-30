<?php
/**
 * Post card used in news grids.
 *
 * @package WorldCruiseAcademy
 */
?>
<article <?php post_class( 'wca-post-card' ); ?>>
	<a class="wca-post-thumb" href="<?php the_permalink(); ?>" aria-hidden="true" tabindex="-1">
		<?php the_post_thumbnail( 'medium_large' ); ?>
	</a>
	<div class="wca-post-body">
		<span class="wca-post-meta"><?php echo esc_html( get_the_date() ); ?></span>
		<h3><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
		<p><?php echo esc_html( get_the_excerpt() ); ?></p>
	</div>
</article>
