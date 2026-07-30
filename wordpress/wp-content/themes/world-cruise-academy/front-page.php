<?php
/**
 * Landing page: hero, programs, why us, stats, enroll CTA, latest news.
 *
 * @package WorldCruiseAcademy
 */

get_header();
?>

<section class="wca-hero">
	<div class="wca-container">
		<h1><?php esc_html_e( 'Launch your career on the world’s finest', 'worldcruiseacademy' ); ?> <span class="wca-gold-text"><?php esc_html_e( 'cruise ships', 'worldcruiseacademy' ); ?></span></h1>
		<p class="wca-sub">
			<?php esc_html_e( 'World Cruise Academy trains you for hospitality, service, and safety roles on board international cruise lines — with hands-on instruction, industry-recognized certification, and job placement support.', 'worldcruiseacademy' ); ?>
		</p>
		<div class="wca-hero-actions">
			<a class="wca-btn wca-btn-primary" href="#enroll"><?php esc_html_e( 'Enroll now', 'worldcruiseacademy' ); ?></a>
			<a class="wca-btn wca-btn-ghost" href="#programs"><?php esc_html_e( 'Explore programs', 'worldcruiseacademy' ); ?></a>
		</div>
		<p class="wca-hero-note"><?php esc_html_e( 'New classes start every month. No prior experience required.', 'worldcruiseacademy' ); ?></p>
	</div>
</section>

<section id="programs" class="wca-section">
	<div class="wca-container">
		<div class="wca-section-head">
			<span class="wca-eyebrow"><?php esc_html_e( 'Training Programs', 'worldcruiseacademy' ); ?></span>
			<h2><?php esc_html_e( 'Programs that get you hired on board', 'worldcruiseacademy' ); ?></h2>
			<p><?php esc_html_e( 'Practical, career-focused courses built around what cruise lines actually look for.', 'worldcruiseacademy' ); ?></p>
		</div>
		<div class="wca-programs">
			<div class="wca-program">
				<div class="wca-program-icon" aria-hidden="true">&#128674;</div>
				<h3><?php esc_html_e( 'Cruise Hospitality Management', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Guest relations, service standards, and shipboard operations — the foundation for every hotel-department role at sea.', 'worldcruiseacademy' ); ?></p>
				<span class="wca-program-tag"><?php esc_html_e( 'Most popular', 'worldcruiseacademy' ); ?></span>
			</div>
			<div class="wca-program">
				<div class="wca-program-icon" aria-hidden="true">&#127869;</div>
				<h3><?php esc_html_e( 'Food & Beverage Service', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Restaurant, bar, and banquet service training to international standards, from silver service to wine basics.', 'worldcruiseacademy' ); ?></p>
				<span class="wca-program-tag"><?php esc_html_e( 'Certificate', 'worldcruiseacademy' ); ?></span>
			</div>
			<div class="wca-program">
				<div class="wca-program-icon" aria-hidden="true">&#128716;</div>
				<h3><?php esc_html_e( 'Housekeeping & Cabin Stewarding', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Stateroom care, laundry operations, and the attention to detail that five-star cruise lines demand.', 'worldcruiseacademy' ); ?></p>
				<span class="wca-program-tag"><?php esc_html_e( 'Certificate', 'worldcruiseacademy' ); ?></span>
			</div>
			<div class="wca-program">
				<div class="wca-program-icon" aria-hidden="true">&#128188;</div>
				<h3><?php esc_html_e( 'Front Office & Guest Services', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Reception, pursers’ desk, and guest problem-solving — the face of the ship, trained to shine.', 'worldcruiseacademy' ); ?></p>
				<span class="wca-program-tag"><?php esc_html_e( 'Certificate', 'worldcruiseacademy' ); ?></span>
			</div>
			<div class="wca-program">
				<div class="wca-program-icon" aria-hidden="true">&#127864;</div>
				<h3><?php esc_html_e( 'Bartending & Barista Skills', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Mixology, coffee craft, and bar management for the ships’ lounges, pool bars, and specialty cafés.', 'worldcruiseacademy' ); ?></p>
				<span class="wca-program-tag"><?php esc_html_e( 'Short course', 'worldcruiseacademy' ); ?></span>
			</div>
			<div class="wca-program">
				<div class="wca-program-icon" aria-hidden="true">&#9981;</div>
				<h3><?php esc_html_e( 'Safety & STCW Preparation', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Prepare for the mandatory STCW basic safety training every crew member needs before joining a ship.', 'worldcruiseacademy' ); ?></p>
				<span class="wca-program-tag"><?php esc_html_e( 'Required for all crew', 'worldcruiseacademy' ); ?></span>
			</div>
		</div>
	</div>
</section>

<section id="why-us" class="wca-section wca-section-alt">
	<div class="wca-container">
		<div class="wca-section-head">
			<span class="wca-eyebrow"><?php esc_html_e( 'Why World Cruise Academy', 'worldcruiseacademy' ); ?></span>
			<h2><?php esc_html_e( 'We train you like you’re already on board', 'worldcruiseacademy' ); ?></h2>
		</div>
		<div class="wca-why">
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#127891;</div>
				<h3><?php esc_html_e( 'Industry instructors', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Learn from trainers with real years of service on international cruise lines.', 'worldcruiseacademy' ); ?></p>
			</div>
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#129309;</div>
				<h3><?php esc_html_e( 'Placement support', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'CV coaching, interview preparation, and direct connections to cruise line recruiters.', 'worldcruiseacademy' ); ?></p>
			</div>
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#128736;</div>
				<h3><?php esc_html_e( 'Hands-on training', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Practice in simulated shipboard settings — real service scenarios, not just slideshows.', 'worldcruiseacademy' ); ?></p>
			</div>
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#127760;</div>
				<h3><?php esc_html_e( 'Global standards', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Curriculum aligned with international maritime and hospitality requirements.', 'worldcruiseacademy' ); ?></p>
			</div>
		</div>
	</div>
</section>

<section class="wca-stats">
	<div class="wca-container">
		<div class="wca-stats-grid">
			<div>
				<div class="wca-stat-number">1,200+</div>
				<div class="wca-stat-label"><?php esc_html_e( 'Graduates trained', 'worldcruiseacademy' ); ?></div>
			</div>
			<div>
				<div class="wca-stat-number">85%</div>
				<div class="wca-stat-label"><?php esc_html_e( 'Job placement rate', 'worldcruiseacademy' ); ?></div>
			</div>
			<div>
				<div class="wca-stat-number">12</div>
				<div class="wca-stat-label"><?php esc_html_e( 'Partner cruise lines', 'worldcruiseacademy' ); ?></div>
			</div>
			<div>
				<div class="wca-stat-number">6</div>
				<div class="wca-stat-label"><?php esc_html_e( 'Career-ready programs', 'worldcruiseacademy' ); ?></div>
			</div>
		</div>
	</div>
</section>

<section id="enroll" class="wca-section wca-cta">
	<div class="wca-container">
		<div class="wca-section-head">
			<span class="wca-eyebrow"><?php esc_html_e( 'Enrollment', 'worldcruiseacademy' ); ?></span>
			<h2><?php esc_html_e( 'Ready to set sail on your new career?', 'worldcruiseacademy' ); ?></h2>
			<p><?php esc_html_e( 'Applications are open for next month’s intake. Seats are limited per class.', 'worldcruiseacademy' ); ?></p>
		</div>
		<div class="wca-hero-actions">
			<a class="wca-btn wca-btn-primary" href="mailto:admissions@worldcruiseacademy.com"><?php esc_html_e( 'Apply by email', 'worldcruiseacademy' ); ?></a>
			<a class="wca-btn wca-btn-outline" href="tel:+10000000000"><?php esc_html_e( 'Call admissions', 'worldcruiseacademy' ); ?></a>
		</div>
		<p class="wca-cta-contact">
			<?php esc_html_e( 'Questions? Write to', 'worldcruiseacademy' ); ?>
			<a href="mailto:admissions@worldcruiseacademy.com">admissions@worldcruiseacademy.com</a>
		</p>
	</div>
</section>

<?php
$wca_posts = new WP_Query(
	array(
		'posts_per_page'      => 3,
		'ignore_sticky_posts' => true,
	)
);

if ( $wca_posts->have_posts() ) :
	?>
	<section id="news" class="wca-section wca-section-alt">
		<div class="wca-container">
			<div class="wca-section-head">
				<span class="wca-eyebrow"><?php esc_html_e( 'News', 'worldcruiseacademy' ); ?></span>
				<h2><?php esc_html_e( 'Latest from the academy', 'worldcruiseacademy' ); ?></h2>
			</div>
			<div class="wca-posts">
				<?php
				while ( $wca_posts->have_posts() ) :
					$wca_posts->the_post();
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
