package main

import "core:fmt"
import "core:time"
import "core:math/rand"
import rl "vendor:raylib"


WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 800

BACKGROUND_COLOR  :: rl.Color{ 20, 20, 30, 255 }

G :: rl.Vector2{ 0, 700 }
G_PARTICLE :: rl.Vector2{ 0, 45 }
FIREWORK_INITIAL_VELOCITY :: rl.Vector2{ 0, -900 }

PARTICLES_MIN :: 100
PARTICLES_MAX :: 200
PARTICLES_MAX_MAX :: 1000
EXPLOSION_RADIUS_MIN :: 30
EXPLOSION_RADIUS_MAX :: 50

PARTICLE_LIFESPAN :: 100
PARTICLE_FRICTION :: rl.Vector2{ 60, 60 }
X_WIGGLE_SCALE :: 0.5
Y_WIGGLE_SCALE :: 0.5


GameEntity :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    color: rl.Color,
    radius: f32,
}

Particle :: struct {
    entity: GameEntity,
    age: i32,
    is_dead: bool,
    n_children: int,
}

Firework :: struct {
    entity: GameEntity,
    is_exploded: bool,
    is_dead: bool,
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

MIN :: proc(a: i32, b: i32) -> u8 {
    if a > b do return u8(b)
    return u8(a)
}

MAX :: proc(a: i32, b: i32) -> u8 {
    if a > b do return u8(a)
    return u8(b)
}

// GameEntity funtions
entity_apply_wiggle :: proc(entity: ^GameEntity) {
    entity.pos += rl.Vector2{ rand.float32_uniform(-1, 1) * X_WIGGLE_SCALE, rand.float32_uniform(-1, 1) * Y_WIGGLE_SCALE }
}

game_entity_physics_update :: proc(game_entity: ^GameEntity, G: rl.Vector2) {
    game_entity.vel += G * rl.GetFrameTime()
    game_entity.pos += game_entity.vel * rl.GetFrameTime()
}

game_entity_draw :: proc(game_entity: GameEntity) {
    rl.DrawCircleV(game_entity.pos, game_entity.radius, game_entity.color)
}

// Firework functions
firework_new :: proc() -> Firework {
    x := rand_range(100, WINDOW_WIDTH - 100)
    vel_randomness := rl.Vector2{ 0, f32(rand_range(-20, 20)) }

    entity := GameEntity{ pos={ f32(x), WINDOW_HEIGHT}, vel=FIREWORK_INITIAL_VELOCITY + vel_randomness,
                          color=rl.RAYWHITE, radius=5}
    firework := Firework{ entity=entity, particles=make([dynamic]Particle) }
    return firework
}

firework_update :: proc(firework: ^Firework) {
    if !firework.is_exploded {
        if firework.entity.vel.y > 0 {
            firework.is_exploded = true
            
            colors := [3]rl.Color{}
            for i in 0..=2 {
                color := rl.Color{u8(rand_range(0, 255)),
                                  u8(rand_range(0, 255)), 
                                  u8(rand_range(0, 255)), 255}
                colors[i] = color
            }

            n_particles := rand_range(PARTICLES_MIN, PARTICLES_MAX)
            for i in 0..=n_particles {
	            color := colors[rand.int63_max(3)]

                vel := rl.Vector2{ rand.float32_uniform(-1, 1), rand.float32_uniform(-1, 1) }
                vel *= rl.Vector2{ f32(rand_range(EXPLOSION_RADIUS_MIN, EXPLOSION_RADIUS_MAX)), 
                                   f32(rand_range(EXPLOSION_RADIUS_MIN, EXPLOSION_RADIUS_MAX)) }

                entity := GameEntity{ pos=firework.entity.pos, vel=vel, color=color, radius=f32(rand_range(2, 5)) }
                particle := Particle{ entity=entity, age=0, is_dead=false }
                append(&firework.particles, particle)
            }
        } else {
            game_entity_physics_update(&firework.entity, G)
        }
        return
    }

    for &particle, i in firework.particles {
        if !particle.is_dead {
            particle.age += 1
            particle.is_dead = particle_decay(particle)

            if particle.n_children < 3 && len(firework.particles) < PARTICLES_MAX_MAX {
                p, ok := particle_generate_trail(&particle.entity)
                if ok {
                    append(&firework.particles, p)
                    particle.n_children += 1
                }
            }

            particle_apply_friction(&particle) 
            entity_apply_wiggle(&particle.entity)
            game_entity_physics_update(&particle.entity, G_PARTICLE)
        }
    }
    
    // if all particles of a firework is dead, the firework is dead as well
    for particle in firework.particles {
        if !particle.is_dead do return
    }
    firework.is_dead = true
}

firework_draw :: proc(firework: Firework) {
    if !firework.is_exploded do game_entity_draw(firework.entity)
    for particle in firework.particles {
        if !particle.is_dead {
            if rand.int31_max(i32(MAX(abs(PARTICLE_LIFESPAN - particle.age), 3))) == 0 do continue
            game_entity_draw(particle.entity)
        }
    }
}

// Particle functions
particle_decay :: proc(particle: Particle) -> bool {
    if particle.age > PARTICLE_LIFESPAN {
        if rand.int31_max(15) == 0 do return true
    }
    if particle.age > PARTICLE_LIFESPAN * 2 do return true
    return false
}

particle_generate_trail :: proc(entity: ^GameEntity) -> (Particle, bool) {
    if entity.radius == 2 do return Particle{}, false
    if rand.int31_max(30) != 0 do return Particle{}, false

    color := entity.color
    color[0] = MIN(i32(color[0]) + 25, 255)
    color[1] = MIN(i32(color[1]) + 25, 255)
    color[2] = MIN(i32(color[2]) + 25, 220)
    entity := GameEntity{ pos=entity.pos, color=color, radius=entity.radius - f32(rand.int31_max(1)) }
    return Particle{ entity=entity }, true
}

particle_apply_friction :: proc(particle: ^Particle) {
    if particle.age > PARTICLE_LIFESPAN / 6 do return
    if particle.age == PARTICLE_LIFESPAN / 6 {
        particle.entity.vel.x = 0
        particle.entity.vel.y = 0
        return
    }

    particle.entity.vel *= PARTICLE_FRICTION * rl.GetFrameTime() * 1.22
}

main :: proc() {
    fireworks := make([dynamic]Firework)
    defer delete(fireworks)
    append(&fireworks, firework_new())

    rl.InitWindow(WINDOW_HEIGHT, WINDOW_WIDTH, "Raylib Fireworks")
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Input
        if rl.IsKeyPressed(.ONE) do append(&fireworks, firework_new())
        if rl.IsKeyPressed(.TWO) do for _ in 0..=10 do append(&fireworks, firework_new())
        
        // Logic
        for &firework, i in fireworks {
            firework_update(&firework)
            if firework.is_dead {
                delete(firework.particles)
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
