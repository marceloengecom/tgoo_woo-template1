<?php
/**
 * Modern Cart Woo floating inner html
 *
 * @package modern-cart
 * @version 0.0.1
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$allowed_svg_tags = [
	'svg'  => [
		'xmlns'           => true,
		'viewBox'         => true,
		'width'           => true,
		'height'          => true,
		'fill'            => true,
		'stroke'          => true,
		'stroke-width'    => true,
		'stroke-linecap'  => true,
		'stroke-linejoin' => true,
	],
	'path' => [
		'd'               => true,
		'fill'            => true,
		'stroke'          => true,
		'stroke-width'    => true,
		'stroke-linecap'  => true,
		'stroke-linejoin' => true,
	],
];
?>

<button class="moderncart-floating-cart-button"
aria-label="
<?php 
/* translators: %d: number of items in cart */
printf( esc_attr__( 'Cart Button with %d items', 'modern-cart' ), esc_attr( $item_account ) );
?>
"
	aria-haspopup="true"
	aria-expanded="false"
	aria-controls="moderncart-slide-out-modal" 
	aria-live="polite"
>
	<div class="moderncart-floating-cart-count">
		<span><?php echo esc_html( $item_account ); ?></span>
	</div>
	<span class="moderncart-floating-cart-icon">
		<?php echo wp_kses( $cart_svg_icons[ (int) $cart_icon ] ?? $cart_svg_icons[0], $allowed_svg_tags ); ?>
	</span>
</button>
