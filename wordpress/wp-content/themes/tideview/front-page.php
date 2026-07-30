<?php
/**
 * Landing page: hero, features, download CTA, latest posts.
 *
 * @package TideView
 */

get_header();
?>

<section class="tv-hero">
	<div class="tv-container">
		<h1><?php esc_html_e( 'Watch the web,', 'tideview' ); ?> <span class="tv-grad"><?php esc_html_e( 'without the noise.', 'tideview' ); ?></span></h1>
		<p class="tv-sub">
			<?php esc_html_e( 'TideView is a fast, minimal YouTube video app. Search instantly, keep watching with the pinned player, and enjoy a dark mode that is easy on the eyes.', 'tideview' ); ?>
		</p>
		<div class="tv-hero-actions">
			<a class="tv-btn tv-btn-primary" href="#download"><?php esc_html_e( 'Get TideView for Android', 'tideview' ); ?></a>
			<a class="tv-btn tv-btn-ghost" href="#features"><?php esc_html_e( 'See features', 'tideview' ); ?></a>
		</div>
		<p class="tv-hero-note"><?php esc_html_e( 'Free. No account required. Built with Flutter.', 'tideview' ); ?></p>

		<div class="tv-phone" aria-hidden="true">
			<div class="tv-phone-screen">
				<div class="tv-phone-player"><span class="tv-phone-play">&#9654;</span></div>
				<div class="tv-phone-row"></div>
				<div class="tv-phone-row short"></div>
				<div class="tv-phone-thumbs">
					<div class="tv-phone-thumb"></div>
					<div class="tv-phone-thumb"></div>
					<div class="tv-phone-thumb"></div>
					<div class="tv-phone-thumb"></div>
				</div>
			</div>
		</div>
	</div>
</section>

<section id="features" class="tv-section tv-section-alt">
	<div class="tv-container">
		<div class="tv-section-head">
			<span class="tv-eyebrow"><?php esc_html_e( 'Features', 'tideview' ); ?></span>
			<h2><?php esc_html_e( 'Everything you need, nothing you don’t', 'tideview' ); ?></h2>
			<p><?php esc_html_e( 'A focused video experience designed around watching — not scrolling.', 'tideview' ); ?></p>
		</div>
		<div class="tv-features">
			<div class="tv-feature">
				<div class="tv-feature-icon" aria-hidden="true">&#128269;</div>
				<h3><?php esc_html_e( 'Instant search', 'tideview' ); ?></h3>
				<p><?php esc_html_e( 'Find any video in seconds with a clean, distraction-free search experience.', 'tideview' ); ?></p>
			</div>
			<div class="tv-feature">
				<div class="tv-feature-icon" aria-hidden="true">&#128204;</div>
				<h3><?php esc_html_e( 'Pinned mini player', 'tideview' ); ?></h3>
				<p><?php esc_html_e( 'Keep watching while you browse — the player docks neatly and follows you around the app.', 'tideview' ); ?></p>
			</div>
			<div class="tv-feature">
				<div class="tv-feature-icon" aria-hidden="true">&#127769;</div>
				<h3><?php esc_html_e( 'True dark mode', 'tideview' ); ?></h3>
				<p><?php esc_html_e( 'A deep, ocean-dark theme designed for late-night viewing without eye strain.', 'tideview' ); ?></p>
			</div>
			<div class="tv-feature">
				<div class="tv-feature-icon" aria-hidden="true">&#128172;</div>
				<h3><?php esc_html_e( 'Smart comments', 'tideview' ); ?></h3>
				<p><?php esc_html_e( 'Comments collapse to two lines and expand on tap, so the conversation never buries the video.', 'tideview' ); ?></p>
			</div>
			<div class="tv-feature">
				<div class="tv-feature-icon" aria-hidden="true">&#127902;</div>
				<h3><?php esc_html_e( 'Related videos & Shorts', 'tideview' ); ?></h3>
				<p><?php esc_html_e( 'Related videos load automatically when the player opens, with Shorts support built in.', 'tideview' ); ?></p>
			</div>
			<div class="tv-feature">
				<div class="tv-feature-icon" aria-hidden="true">&#128241;</div>
				<h3><?php esc_html_e( 'Fullscreen & landscape', 'tideview' ); ?></h3>
				<p><?php esc_html_e( 'Rotate for edge-to-edge fullscreen playback that just works, every time.', 'tideview' ); ?></p>
			</div>
		</div>
	</div>
</section>

<section id="download" class="tv-section tv-cta">
	<div class="tv-container">
		<div class="tv-section-head">
			<span class="tv-eyebrow"><?php esc_html_e( 'Download', 'tideview' ); ?></span>
			<h2><?php esc_html_e( 'Ready to ride the tide?', 'tideview' ); ?></h2>
			<p><?php esc_html_e( 'TideView is available for Android today, with iOS on the way.', 'tideview' ); ?></p>
		</div>
		<div class="tv-hero-actions">
			<a class="tv-btn tv-btn-primary" href="https://github.com/mustang77/tideview"><?php esc_html_e( 'Download for Android', 'tideview' ); ?></a>
			<a class="tv-btn tv-btn-ghost" href="https://github.com/mustang77/tideview"><?php esc_html_e( 'View on GitHub', 'tideview' ); ?></a>
		</div>
	</div>
</section>

<?php
$tideview_posts = new WP_Query(
	array(
		'posts_per_page'      => 3,
		'ignore_sticky_posts' => true,
	)
);

if ( $tideview_posts->have_posts() ) :
	?>
	<section id="blog" class="tv-section tv-section-alt">
		<div class="tv-container">
			<div class="tv-section-head">
				<span class="tv-eyebrow"><?php esc_html_e( 'Blog', 'tideview' ); ?></span>
				<h2><?php esc_html_e( 'Latest from the crew', 'tideview' ); ?></h2>
			</div>
			<div class="tv-posts">
				<?php
				while ( $tideview_posts->have_posts() ) :
					$tideview_posts->the_post();
					get_template_part( 'template-parts/content', 'card' );
				endwhile;
				wp_reset_postdata();
				?>
			</div>
		</div>
	</section>
<?php endif; ?>

<?php
get_footer();
