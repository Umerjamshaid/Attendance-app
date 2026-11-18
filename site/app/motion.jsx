"use client";

import { useEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import Lenis from "lenis";

export function Motion() {
  useEffect(() => {
    gsap.registerPlugin(ScrollTrigger);
    const media = gsap.matchMedia();
    media.add("(prefers-reduced-motion: no-preference)", () => {
      const lenis = new Lenis({ autoRaf: false, anchors: false });
      const tick = (seconds) => lenis.raf(seconds * 1000);
      lenis.on("scroll", ScrollTrigger.update);
      gsap.ticker.add(tick);

      gsap.timeline({ defaults: { ease: "power3.out" } })
        .from("[data-hero-title] span", { y: 14, duration: .6, stagger: .08 })
        .from("[data-hero-copy], [data-hero-actions]", { y: 8, duration: .5, stagger: .08 }, .12)
        .from(".hero-shot .phone", { y: 38, opacity: .65, duration: .8, stagger: .08 }, .15);

      for (const heading of document.querySelectorAll("[data-reveal]")) {
        gsap.from(heading.children, {
          y: 15,
          opacity: .72,
          duration: .58,
          stagger: .055,
          ease: "power2.out",
          scrollTrigger: { trigger: heading, start: "top 88%", once: true },
        });
      }

      let active = true;
      document.fonts.ready.then(() => {
        if (active) ScrollTrigger.refresh();
      });
      return () => {
        active = false;
        gsap.ticker.remove(tick);
        lenis.destroy();
      };
    });
    media.add("(min-width: 641px) and (prefers-reduced-motion: no-preference)", () => {
      gsap.timeline({
        scrollTrigger: {
          trigger: ".hero",
          start: "top top",
          end: "bottom top",
          scrub: .65,
        },
        defaults: { ease: "none" },
      })
        .to(".hero-shot-left", { x: -47, y: -20, rotation: -15 }, 0)
        .to(".hero-shot-right", { x: 47, y: -20, rotation: 15 }, 0)
        .to(".hero-shot-center", { y: -32 }, 0);
    });
    return () => media.revert();
  }, []);
  return null;
}
