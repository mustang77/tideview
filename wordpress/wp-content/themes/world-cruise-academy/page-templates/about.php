<?php
/**
 * Template Name: About
 *
 * About the academy: mission, story, values.
 *
 * @package WorldCruiseAcademy
 */

get_header();
?>

<section class="wca-page-hero">
	<div class="wca-container">
		<span class="wca-eyebrow"><?php esc_html_e( 'About Us', 'worldcruiseacademy' ); ?></span>
		<h1><?php esc_html_e( 'About World Cruise Academy', 'worldcruiseacademy' ); ?></h1>
		<p><?php esc_html_e( 'Training the next generation of cruise ship professionals.', 'worldcruiseacademy' ); ?></p>
	</div>
</section>

<section class="wca-section">
	<div class="wca-container wca-about">
		<div class="wca-about-block">
			<h2><?php esc_html_e( 'Our mission', 'worldcruiseacademy' ); ?></h2>
			<p><?php esc_html_e( 'The cruise industry hires tens of thousands of new crew members every year — but ships promote and retain the people who arrive trained, confident, and ready to serve. World Cruise Academy exists to close that gap. We take motivated people, with or without prior experience, and prepare them to walk up the gangway ready to work.', 'worldcruiseacademy' ); ?></p>
		</div>

		<div class="wca-about-block">
			<h2><?php esc_html_e( 'How we teach', 'worldcruiseacademy' ); ?></h2>
			<p><?php esc_html_e( 'Every course is built around practice, not slideshows. Our training rooms simulate shipboard settings — a dining room laid for service, a mock cabin section, a working bar — and our instructors are former cruise ship crew and officers who know exactly what supervisors on board expect. You will drill real scenarios until the standard becomes second nature.', 'worldcruiseacademy' ); ?></p>
		</div>

		<div class="wca-about-block">
			<h2><?php esc_html_e( 'Beyond the classroom', 'worldcruiseacademy' ); ?></h2>
			<p><?php esc_html_e( 'Graduating is the midpoint, not the finish line. We coach you through your CV and application photos, run mock interviews modeled on real cruise line hiring, guide you through the medical and documentation requirements, and connect you with recruiters at our partner lines. Our team stays with you until you have a contract in hand.', 'worldcruiseacademy' ); ?></p>
		</div>

		<div class="wca-values">
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#11088;</div>
				<h3><?php esc_html_e( 'Excellence', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Five-star standards in everything we teach and everything we do.', 'worldcruiseacademy' ); ?></p>
			</div>
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#129504;</div>
				<h3><?php esc_html_e( 'Practicality', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Skills you will actually use in your first week on board.', 'worldcruiseacademy' ); ?></p>
			</div>
			<div class="wca-why-item">
				<div class="wca-why-icon" aria-hidden="true">&#128156;</div>
				<h3><?php esc_html_e( 'Care', 'worldcruiseacademy' ); ?></h3>
				<p><?php esc_html_e( 'Small classes, personal attention, and support that continues after graduation.', 'worldcruiseacademy' ); ?></p>
			</div>
		</div>

		<?php if ( get_the_content() ) : ?>
			<div class="wca-article-content wca-about-block">
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
