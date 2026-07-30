<?php
/**
 * Site header.
 *
 * @package TideView
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
<a class="skip-link" href="#tv-main"><?php esc_html_e( 'Skip to content', 'tideview' ); ?></a>

<header class="tv-header">
	<div class="tv-header-inner">
		<a class="tv-brand" href="<?php echo esc_url( home_url( '/' ) ); ?>">
			<span class="tv-wave" aria-hidden="true">&#9654;</span>
			<?php bloginfo( 'name' ); ?>
		</a>
		<nav class="tv-nav" aria-label="<?php esc_attr_e( 'Primary', 'tideview' ); ?>">
			<?php
			wp_nav_menu(
				array(
					'theme_location' => 'primary',
					'container'      => false,
					'fallback_cb'    => 'tideview_default_menu',
					'depth'          => 1,
				)
			);
			?>
		</nav>
	</div>
</header>

<main id="tv-main">
