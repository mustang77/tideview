<?php
/**
 * Site header.
 *
 * @package WorldCruiseAcademy
 */
?>
<!doctype html>
<html <?php language_attributes(); ?>>
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<a class="skip-link" href="#wca-main"><?php esc_html_e( 'Skip to content', 'worldcruiseacademy' ); ?></a>

<header class="wca-header">
	<div class="wca-header-inner">
		<a class="wca-brand" href="<?php echo esc_url( home_url( '/' ) ); ?>">
			<span class="wca-anchor" aria-hidden="true">&#9875;</span>
			<?php bloginfo( 'name' ); ?>
		</a>
		<nav class="wca-nav" aria-label="<?php esc_attr_e( 'Primary', 'worldcruiseacademy' ); ?>">
			<?php
			wp_nav_menu(
				array(
					'theme_location' => 'primary',
					'container'      => false,
					'fallback_cb'    => 'wca_default_menu',
					'depth'          => 1,
				)
			);
			?>
		</nav>
	</div>
</header>

<main id="wca-main">
