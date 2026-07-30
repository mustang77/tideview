<?php
/**
 * Site footer.
 *
 * @package WorldCruiseAcademy
 */
?>
</main>

<footer class="wca-footer">
	<div class="wca-container wca-footer-inner">
		<p>&copy; <?php echo esc_html( gmdate( 'Y' ) ); ?> <?php bloginfo( 'name' ); ?>. <?php esc_html_e( 'Your career at sea starts here.', 'worldcruiseacademy' ); ?></p>
		<nav class="wca-footer-nav" aria-label="<?php esc_attr_e( 'Footer', 'worldcruiseacademy' ); ?>">
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
