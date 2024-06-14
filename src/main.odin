package main

import "core:fmt"
import "core:time"
import "core:math/rand"
import rl "vendor:raylib"


WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 800

BACKGROUND_COLOR  :: rl.Color{ 20, 20, 30, 255 }

G :: rl.Vector2{ 0, 700 }
G_PARTICLE :: rl.Vector2{ 0, 75 }
FIREWORK_INITIAL_VELOCITY :: rl.Vector2{ 0, -900 }
PARTICLE_INITIAL_VELOCITY :: rl.Vector2{ 0, -40 }

PARTICLES_MIN :: 100
PARTICLES_MAX :: 200
EXPLOSION_RADIUS_MIN :: 25
EXPLOSION_RADIUS_MAX :: 40

PARTICLE_LIFESPAN :: 100
PARTICLE_FRICTION :: rl.Vector2{ 60, 60 }
X_WIGGLE_SCALE :: 0.5
Y_WIGGLE_SCALE :: 0.5

TRAIL_FREQUENCY :: 5 


GameEntity :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    color: rl.Color,
    radius: i32,
}

Particle :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    color: rl.Color,
    radius: i32,
    age: i32,
    is_dead: bool,
}

Firework :: struct {
    color: rl.Color,
    is_exploded: bool,
    main_particle: Particle,
    particles: [dynamic]Particle,
}

// Helpers
rand_range :: proc(left: i32, right: i32) -> i32 {
    max_ := right
    min_ := left
    if left > right {
        max_ = left
        min_ = right
    }
    x := rand.int31_max(max_ - min_)
    x += abs(min_)
    return x
}

// Firework functions
firework_new :: proc() -> Firework {
    x := rand_range(100, WINDOW_WIDTH - 100)
    vel_randomness := rl.Vector2{ 0, f32(rand_range(-20, 20)) }
    particle := Particle{ pos={f32(x), WINDOW_HEIGHT}, vel=FIREWORK_INITIAL_VELOCITY + vel_randomness, radius=5 }
    firework := Firework{ color=rl.RAYWHITE, is_exploded=false, main_particle=particle }
    firework.main_particle.color = firework.color
    return firework
}

firework_update :: proc(firework: ^Firework) {
    if !firework.is_exploded {
        particle_update_pos(&firework.main_particle, G)
        
        if firework.main_particle.vel.y > 0 {
            firework.is_exploded = true
            
            colors := [3]rl.Color{}
            for i in 0..=2 {
                color := rl.Color{u8(rand_range(0, 255)),
                                  u8(rand_range(0, 255)), 
                                  u8(rand_range(0, 255)), 255}
                colors[i] = color
            }

            // create particles
            n_particles := rand_range(PARTICLES_MIN, PARTICLES_MAX)
            for i in 0..=n_particles {
	            color := colors[rand.int63_max(3)]

                vel := rl.Vector2{ rand.float32_uniform(-1, 1), rand.float32_uniform(-1, 1) }
                vel *= rl.Vector2{ f32(rand_range(EXPLOSION_RADIUS_MIN, EXPLOSION_RADIUS_MAX)), 
                                   f32(rand_range(EXPLOSION_RADIUS_MIN, EXPLOSION_RADIUS_MAX)) }

                p := Particle{ pos=firework.main_particle.pos, vel=vel, color=color, radius=3 }
                append(&firework.particles, p)
            }
        }
        return
    }

    for &particle, i in firework.particles {
        if particle.is_dead do continue
        particle.age += 1
        particle.is_dead = particle_decay(particle)
        particle_apply_friction(&particle) 
        particle_apply_wiggle(&particle)
        particle_update_pos(&firework.particles[i], G_PARTICLE)
    }
    
    // if all particle of a firework is dead, the main firework particle is dead as well
    for particle in firework.particles {
        if !particle.is_dead do return
    }
    firework.main_particle.is_dead = true
}

firework_draw :: proc(firework: Firework) {
    if !firework.is_exploded do particle_draw(firework.main_particle)

    for particle, i in firework.particles {
        particle_draw(particle)
    }
}

// Particle functions
particle_update_pos :: proc(particle: ^Particle, G: rl.Vector2) {
    particle.vel += G * rl.GetFrameTime()
    particle.pos += particle.vel * rl.GetFrameTime()
}

particle_decay :: proc(particle: Particle) -> bool {
        if particle.age > PARTICLE_LIFESPAN {
            if rand.int31_max(15) == 0 do return true
        }
        if particle.age > PARTICLE_LIFESPAN * 2 do return true
        return false
}

particle_apply_friction :: proc(particle: ^Particle) {
    if particle.age > PARTICLE_LIFESPAN / 6 do return
    if particle.age == PARTICLE_LIFESPAN / 6 {
        particle.vel.x = 0
        particle.vel.y = 0
        return
    }

    particle.vel *= PARTICLE_FRICTION * rl.GetFrameTime() * 1.22
}

particle_apply_wiggle :: proc(particle: ^Particle) {
    particle.pos += rl.Vector2{ rand.float32_uniform(-1, 1) * X_WIGGLE_SCALE, rand.float32_uniform(-1, 1) * Y_WIGGLE_SCALE }
}


particle_draw :: proc(particle: Particle) {
    if particle.is_dead do return
    rl.DrawCircleV(particle.pos, f32(particle.radius), particle.color)
}

main :: proc() {
    fireworks := make([dynamic]Firework)
    defer delete(fireworks)

    append(&fireworks, firework_new())
    // TODO: remove firework from fireworks

    rl.InitWindow(WINDOW_HEIGHT, WINDOW_WIDTH, "Raylib Fireworks")
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Input
        if rl.IsKeyPressed(.ONE) do append(&fireworks, firework_new())
        if rl.IsKeyPressed(.TWO) do for _ in 0..=10 do append(&fireworks, firework_new())
        if rl.IsKeyPressed(.THREE) do for _ in 0..=100 do append(&fireworks, firework_new())
        
        // Logic
        for &firework, i in fireworks {
            firework_update(&firework)
            if firework.main_particle.is_dead {
                unordered_remove(&fireworks, i)
            }
        }

        // Draw
        rl.DrawFPS(30, 30)
        rl.BeginDrawing()
        rl.ClearBackground(BACKGROUND_COLOR)
        for firework in fireworks do firework_draw(firework)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}
