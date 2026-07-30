<?php
/**
 * Site footer.
 *
 * @package TideView
 */
?>
</main>

<footer class="tv-footer">
	<div class="tv-container tv-footer-inner">
		<p>&copy; <?php echo esc_html( gmdate( 'Y' ) ); ?> <?php bloginfo( 'name' ); ?>. <?php esc_html_e( 'Ride the tide.', 'tideview' ); ?></p>
		<nav class="tv-footer-nav" aria-label="<?php esc_attr_e( 'Footer', 'tideview' ); ?>">
			<?php
			wp_nav_menu(
				array(
					'theme_location' => 'footer',
					'container'      => false,
					'fallback_cb'    => false,
					'depth'          => 1,
				)
			);
			?>
		</nav>
	</div>
</footer>

<?php wp_footer(); ?>
</body>
</html>
