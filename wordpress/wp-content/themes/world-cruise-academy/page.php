<?php
/**
 * Static page.
 *
 * @package WorldCruiseAcademy
 */

get_header();

while ( have_posts() ) :
	the_post();
	?>
	<article <?php post_class( 'wca-article' ); ?>>
		<header class="wca-article-header">
			<h1><?php the_title(); ?></h1>
		</header>
		<div class="wca-article-content">
			<?php the_content(); ?>
		</div>
	</article>
	<?php
endwhile;

get_footer();
