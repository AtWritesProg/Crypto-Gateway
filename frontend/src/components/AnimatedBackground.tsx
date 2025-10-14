import { motion } from "framer-motion";

const AnimatedBackground = () => {
  // Reduced to 3 gradient orbs for simplicity
  const shapes = [
    { size: 400, x: "15%", y: "25%", delay: 0 },
    { size: 350, x: "75%", y: "15%", delay: 1 },
    { size: 300, x: "60%", y: "70%", delay: 2 },
  ];

  return (
    <div className="fixed inset-0 overflow-hidden pointer-events-none -z-10">
      {/* Simple Gradient Orbs */}
      {shapes.map((shape, i) => (
        <motion.div
          key={i}
          className="absolute rounded-full blur-3xl opacity-15"
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
            y: [0, -20, 0],
            scale: [1, 1.05, 1],
          }}
          transition={{
            duration: 10 + i * 2,
            repeat: Infinity,
            delay: shape.delay,
            ease: "easeInOut",
          }}
        />
      ))}
    </div>
  );
};

export default AnimatedBackground;
