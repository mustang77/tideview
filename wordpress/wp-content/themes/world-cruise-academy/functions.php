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

/**
 * On theme activation, create the site's pages, set the front/posts pages,
 * and build the primary menu — so the site is multi-page out of the box.
 * Existing pages (matched by slug) are never duplicated or overwritten.
 */
function wca_create_default_content() {
	$pages = array(
		'home'       => array(
			'title'    => __( 'Home', 'worldcruiseacademy' ),
			'template' => '',
		),
		'programs'   => array(
			'title'    => __( 'Programs', 'worldcruiseacademy' ),
			'template' => 'page-templates/programs.php',
		),
		'about'      => array(
			'title'    => __( 'About Us', 'worldcruiseacademy' ),
			'template' => 'page-templates/about.php',
		),
		'news'       => array(
			'title'    => __( 'News', 'worldcruiseacademy' ),
			'template' => '',
		),
		'admissions' => array(
			'title'    => __( 'Contact & Admissions', 'worldcruiseacademy' ),
			'template' => 'page-templates/contact.php',
		),
	);

	$page_ids = array();

	foreach ( $pages as $slug => $page ) {
		$existing = get_page_by_path( $slug );
		if ( $existing instanceof WP_Post ) {
			$page_ids[ $slug ] = $existing->ID;
			continue;
		}

		$page_ids[ $slug ] = wp_insert_post(
			array(
				'post_title'   => $page['title'],
				'post_name'    => $slug,
				'post_status'  => 'publish',
				'post_type'    => 'page',
				'page_template' => $page['template'],
			)
		);
	}

	if ( ! empty( $page_ids['home'] ) && ! empty( $page_ids['news'] ) ) {
		update_option( 'show_on_front', 'page' );
		update_option( 'page_on_front', $page_ids['home'] );
		update_option( 'page_for_posts', $page_ids['news'] );
	}

	$menu = wp_get_nav_menu_object( 'Primary' );
	if ( ! $menu ) {
		$menu_id    = wp_create_nav_menu( 'Primary' );
		$menu_order = array( 'home', 'programs', 'about', 'news', 'admissions' );

		foreach ( $menu_order as $slug ) {
			if ( empty( $page_ids[ $slug ] ) ) {
				continue;
			}
			wp_update_nav_menu_item(
				$menu_id,
				0,
				array(
					'menu-item-object-id' => $page_ids[ $slug ],
					'menu-item-object'    => 'page',
					'menu-item-type'      => 'post_type',
					'menu-item-status'    => 'publish',
				)
			);
		}

		$locations            = get_theme_mod( 'nav_menu_locations', array() );
		$locations['primary'] = $menu_id;
		$locations['footer']  = $menu_id;
		set_theme_mod( 'nav_menu_locations', $locations );
	}
}
add_action( 'after_switch_theme', 'wca_create_default_content' );

function wca_excerpt_length( $length ) {
	return 24;
}
add_filter( 'excerpt_length', 'wca_excerpt_length' );

function wca_excerpt_more( $more ) {
	return '&hellip;';
}
add_filter( 'excerpt_more', 'wca_excerpt_more' );
