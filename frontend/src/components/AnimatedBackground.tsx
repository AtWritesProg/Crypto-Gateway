import { motion } from "framer-motion";

const AnimatedBackground = () => {
  const shapes = [
    { size: 300, x: "10%", y: "20%", delay: 0 },
    { size: 200, x: "80%", y: "10%", delay: 2 },
    { size: 250, x: "70%", y: "70%", delay: 1 },
    { size: 180, x: "20%", y: "80%", delay: 3 },
    { size: 220, x: "50%", y: "50%", delay: 1.5 },
  ];

  return (
    <div className="fixed inset-0 overflow-hidden pointer-events-none -z-10">
      {/* Gradient Orbs */}
      {shapes.map((shape, i) => (
        <motion.div
          key={i}
          className="absolute rounded-full blur-3xl opacity-20"
          style={{
            width: shape.size,
            height: shape.size,
            left: shape.x,
            top: shape.y,
            background: i % 2 === 0 
              ? "radial-gradient(circle, hsl(var(--primary)) 0%, transparent 70%)"
              : "radial-gradient(circle, hsl(var(--cyan)) 0%, transparent 70%)",
          }}
          animate={{
            y: [0, -30, 0],
            x: [0, 20, 0],
            scale: [1, 1.1, 1],
          }}
          transition={{
            duration: 8 + i,
            repeat: Infinity,
            delay: shape.delay,
            ease: "easeInOut",
          }}
        />
      ))}

      {/* Floating Geometric Shapes */}
      {[...Array(8)].map((_, i) => (
        <motion.div
          key={`geo-${i}`}
          className="absolute"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
          }}
          animate={{
            y: [0, -100, 0],
            rotate: [0, 360],
            opacity: [0.1, 0.3, 0.1],
          }}
          transition={{
            duration: 15 + i * 2,
            repeat: Infinity,
            ease: "linear",
          }}
        >
          <div 
            className={`w-4 h-4 border-2 ${
              i % 3 === 0 ? "border-primary" : i % 3 === 1 ? "border-cyan" : "border-accent-pink"
            } ${i % 2 === 0 ? "rounded-full" : ""}`}
          />
        </motion.div>
      ))}

      {/* Grid Pattern Overlay */}
      <div 
        className="absolute inset-0 opacity-5"
        style={{
          backgroundImage: `
            linear-gradient(hsl(var(--primary)) 1px, transparent 1px),
            linear-gradient(90deg, hsl(var(--primary)) 1px, transparent 1px)
          `,
          backgroundSize: "50px 50px",
        }}
      />
    </div>
  );
};

export default AnimatedBackground;
