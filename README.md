# Duel at Dusk
Duel at Dusk is a two-player, turn-based projectile game developed in Easy68k assembly. Players take turns adjusting their projectile’s angle and power to launch stones at their opponent on a battlefield. But beware – challenging wind forces add complexity to each shot, requiring precise calculation and careful judgment to emerge victorious.

## Game Mechanics
Gameplay: Players alternate turns to adjust the angle and power of their projectile, aiming to hit their opponent. Factors like wind direction and speed make each turn unique and challenging.
Win Condition: The game ends when one player's health reaches zero. The dynamic game-over screen will display the winner.

## Technical Features:

## Memory Management

- A custom memory manager was developed to handle efficient memory allocation, deallocation, and optimization. This was key to rendering graphics and managing the dynamic elements in the game:

  - Heap Initialization: Reserves memory space at the start of the game for smooth performance.

  - Memory Allocation: Allocates memory based on availability and creates free blocks when memory is no longer needed.

  - Memory Shrinking: Dynamically reduces allocated blocks based on actual use, which is particularly useful for optimized rendering.

  - Coalescing Free Blocks: Consolidates adjacent free blocks to create larger blocks available for future allocations.

  - Memory Deallocation: Frees specific memory blocks when they’re no longer in use, preventing memory leaks.

- The memory manager supports bitmap rendering and dynamic creation/destruction of projectiles during gameplay.

## Bitmap Rendering
- Bitmap rendering was designed and optimized to maintain a consistent frame rate while rendering visual game elements:

  - Sprite Extraction: Specific blocks of bitmaps are rendered selectively, enabling the use of sprite sheets and minimizing memory use.

  - Optimized Renderer: The rendering loop was optimized to reduce cycles per frame, increasing frame rates to around 30-40 FPS.

  - Transparency Handling: Transparent bitmaps allow for smoother visuals and immersive gameplay, which are especially useful for elements like power and wind meters.

  - Background Redraws: Background bitmaps are redrawn before moving elements, creating smooth animation for moving objects such as projectiles and health indicators.

## Physics Calculations (Fixed-Point Math)
- Physics was implemented using a 12.4 fixed-point math system for fractional accuracy in projectile motion:

  - Projectile Motion: Physics equations, such as those for velocity and position, were calculated using lookup tables for sine and cosine values.

  - Multiplication Constraints: Since 68k handles only 16-bit values, pre-shifting and bit manipulation were used to manage accurate fixed-point multiplication, adding realistic physics to each shot.

## Collision Detection
- Collisions between the projectile and players were implemented with a bounding-box system:

  - Bounding Boxes: Each projectile and player has a box collider. Collision detection is performed using the bounds of these colliders.

  - Hitboxes: Different hit areas were added to the player’s head, body, and legs to allow varying impact effects, making the gameplay more engaging.

## 7-Segment Display
- Seven-segment displays are used for visual indicators of health and wind speed:

  - Digit Representation: Each digit is shown using a custom logic for segment control based on the value that needs to be displayed.

  - Switch-Case Logic: Manages to turn segments on and off based on numerical values, providing a simple yet effective UI for gameplay.

## Randomization
- Wind direction and speed are randomized using a pseudo-random generator:

  - Timestamp Bits: The game utilizes a few bits from the current timestamp to randomize wind properties, adding an element of unpredictability.

## Sprite Animations
- Basic sprite animations were implemented for added visual appeal:

  - Throw Animation: Sprites animate the throw action, giving life to the characters.

  - Hit Animation: Characters react visually when hit, enhancing the game’s immersive feel.

## Additional Game Features
- Start Screen: A custom start screen for players to begin the game.

- Dynamic Game Over Screen: Displays the winner after each round.

- Game Restart Capability: Allows players to restart a new game without relaunching the program.

- Sound Effects: Sound effects enhance player actions, including background music, throwing and impact sounds, and wind sounds.

## Installation and Setup
- To play Duel at Dusk on Easy68k:

  - Clone or download the repository.

  - Open the DuelAtDusk.X68 file in the Easy68k environment.

  - Assemble and run the program to start playing.

### Controls
- Angle Control: Player 1 uses the A and D keys to adjust the projectile angle whereas Player 2 uses the left and right arrow keys.

- Adjust Power: Player 1 uses 'Space' to control the power whereas Player 2 uses 'CTRL' to control the power. Hold down the power button to gradually increase the power you shoot with.

- Launch Projectile: Release the power button when ready to fire

## Development Insights
- Developing Duel at Dusk involved optimizing for low-level assembly constraints, and managing memory and processing cycles carefully to maintain visual performance while implementing complex features like physics and collision detection.
