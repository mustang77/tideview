<?php
/**
 * Single post.
 *
 * @package WorldCruiseAcademy
 */

get_header();

while ( have_posts() ) :
	the_post();
	?>
	<article <?php post_class( 'wca-article' ); ?>>
		<header class="wca-article-header">
			<span class="wca-post-meta"><?php echo esc_html( get_the_date() ); ?> &middot; <?php the_author(); ?></span>
			<h1><?php the_title(); ?></h1>
		</header>
		<?php if ( has_post_thumbnail() ) : ?>
			<figure><?php the_post_thumbnail( 'large' ); ?></figure>
		<?php endif; ?>
		<div class="wca-article-content">
			<?php the_content(); ?>
		</div>
	</article>
	<?php
	if ( comments_open() || get_comments_number() ) {
		echo '<div class="wca-article">';
		comments_template();
		echo '</div>';
	}
endwhile;

get_footer();
