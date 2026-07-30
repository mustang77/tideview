<?php
/**
 * Static page.
 *
 * @package TideView
 */

get_header();

while ( have_posts() ) :
	the_post();
	?>
	<article <?php post_class( 'tv-article' ); ?>>
		<header class="tv-article-header">
			<h1><?php the_title(); ?></h1>
		</header>
		<div class="tv-article-content">
			<?php the_content(); ?>
		</div>
	</article>
	<?php
endwhile;

get_footer();
