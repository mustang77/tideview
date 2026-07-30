<?php
/**
 * Template Name: Contact & Admissions
 *
 * How to apply, contact details, and location.
 *
 * @package WorldCruiseAcademy
 */

get_header();
?>

<section class="wca-page-hero">
	<div class="wca-container">
		<span class="wca-eyebrow"><?php esc_html_e( 'Admissions', 'worldcruiseacademy' ); ?></span>
		<h1><?php esc_html_e( 'Contact & Admissions', 'worldcruiseacademy' ); ?></h1>
		<p><?php esc_html_e( 'Applications are open. New classes start every month.', 'worldcruiseacademy' ); ?></p>
	</div>
</section>

<section class="wca-section">
	<div class="wca-container">
		<div class="wca-section-head">
			<h2><?php esc_html_e( 'How to apply', 'worldcruiseacademy' ); ?></h2>
		</div>
		<ol class="wca-steps">
			<li>
				<h3><?php esc_html_e( 'Choose your program', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Browse the programs page and pick the course that fits your career goal. Not sure? Contact us and we will advise you.', 'worldcruiseacademy' ); ?></p>
			</li>
			<li>
				<h3><?php esc_html_e( 'Send your application', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Email us your full name, the program you want, your phone number, and a short note about yourself. No prior experience is required.', 'worldcruiseacademy' ); ?></p>
			</li>
			<li>
				<h3><?php esc_html_e( 'Interview & enrollment', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'We will invite you for a short interview, confirm your seat, and send you everything you need for your first day.', 'worldcruiseacademy' ); ?></p>
			</li>
		</ol>

		<div class="wca-contact-cards">
			<div class="wca-contact-card">
				<div class="wca-why-icon" aria-hidden="true">&#9993;</div>
				<h3><?php esc_html_e( 'Email', 'worldcruiseacademy' ); ?></h3>
				<p><a href="mailto:admissions@worldcruiseacademy.com">admissions@worldcruiseacademy.com</a></p>
			</div>
			<div class="wca-contact-card">
				<div class="wca-why-icon" aria-hidden="true">&#128222;</div>
				<h3><?php esc_html_e( 'Phone / WhatsApp', 'worldcruiseacademy' ); ?></h3>
				<p><a href="tel:+10000000000">+1 (000) 000-0000</a></p>
			</div>
			<div class="wca-contact-card">
				<div class="wca-why-icon" aria-hidden="true">&#128205;</div>
				<h3><?php esc_html_e( 'Visit us', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( '123 Harbor Street, Your City', 'worldcruiseacademy' ); ?><br><?php esc_html_e( 'Mon–Fri, 9:00–17:00', 'worldcruiseacademy' ); ?></p>
			</div>
		</div>

		<?php if ( get_the_content() ) : ?>
			<div class="wca-article-content" style="max-width: 720px; margin: 48px auto 0;">
				<?php
				while ( have_posts() ) :
					the_post();
					the_content();
				endwhile;
				?>
			</div>
		<?php endif; ?>
	</div>
</section>

<?php
get_footer();
