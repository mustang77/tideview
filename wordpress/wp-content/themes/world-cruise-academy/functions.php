<?php
/**
 * World Cruise Academy theme setup and hooks.
 *
 * @package WorldCruiseAcademy
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'WCA_VERSION', '1.0.0' );

function wca_setup() {
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'custom-logo' );
	add_theme_support( 'automatic-feed-links' );
	add_theme_support( 'responsive-embeds' );
	add_theme_support(
		'html5',
		array( 'search-form', 'comment-form', 'comment-list', 'gallery', 'caption', 'style', 'script' )
	);

	register_nav_menus(
		array(
			'primary' => __( 'Primary Menu', 'worldcruiseacademy' ),
			'footer'  => __( 'Footer Menu', 'worldcruiseacademy' ),
		)
	);
}
add_action( 'after_setup_theme', 'wca_setup' );

function wca_scripts() {
	wp_enqueue_style( 'wca-style', get_stylesheet_uri(), array(), WCA_VERSION );
}
add_action( 'wp_enqueue_scripts', 'wca_scripts' );

/**
 * Fallback primary menu: landing-page anchors until a menu is assigned.
 */
function wca_default_menu() {
	$home = esc_url( home_url( '/' ) );
	echo '<ul>';
	echo '<li><a href="' . $home . '#programs">' . esc_html__( 'Programs', 'worldcruiseacademy' ) . '</a></li>';
	echo '<li><a href="' . $home . '#why-us">' . esc_html__( 'Why Us', 'worldcruiseacademy' ) . '</a></li>';
	echo '<li><a href="' . $home . '#news">' . esc_html__( 'News', 'worldcruiseacademy' ) . '</a></li>';
	echo '<li><a href="' . $home . '#enroll">' . esc_html__( 'Enroll', 'worldcruiseacademy' ) . '</a></li>';
	echo '</ul>';
}

function wca_excerpt_length( $length ) {
	return 24;
}
add_filter( 'excerpt_length', 'wca_excerpt_length' );

function wca_excerpt_more( $more ) {
	return '&hellip;';
}
add_filter( 'excerpt_more', 'wca_excerpt_more' );
