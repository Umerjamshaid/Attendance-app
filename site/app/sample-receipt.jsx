"use client";

import { useLayoutEffect, useRef, useState } from "react";
import gsap from "gsap";
import { MorphSVGPlugin } from "gsap/MorphSVGPlugin";

const ring = "M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18";
const check = "M4.5 12.5l5 5L20 7";

export function SampleReceipt() {
  const root = useRef(null);
  const [complete, setComplete] = useState(false);

  useLayoutEffect(() => {
    gsap.registerPlugin(MorphSVGPlugin);
    const media = gsap.matchMedia(root.current);
    media.add("(prefers-reduced-motion: no-preference)", () => {
      const diameter = root.current.clientWidth * .44;
      const timeline = gsap.timeline({ onComplete: () => setComplete(true) });
      timeline
        .fromTo(".sample-receipt", {
          width: diameter,
          height: diameter,
          borderRadius: diameter,
          color: "#ffffff",
          backgroundColor: "#4b571f",
          scale: .94,
        }, { scale: 1, duration: .28, ease: "back.out(2)" })
        .fromTo(".receipt-mark", { left: "50%", xPercent: -50 }, {
          left: 17,
          xPercent: 0,
          duration: .48,
          ease: "power3.inOut",
        }, .26)
        .fromTo(".receipt-mark path", { attr: { d: ring } }, {
          morphSVG: check,
          duration: .44,
          ease: "power2.inOut",
        }, .18)
        .to(".sample-receipt", {
          width: "88%",
          height: 76,
          borderRadius: 8,
          color: "#17372b",
          backgroundColor: "#e4efc8",
          duration: .58,
          ease: "power3.inOut",
        }, .22)
        .from(".receipt-copy", { autoAlpha: 0, x: -7, duration: .25 }, .53);
    });
    media.add("(prefers-reduced-motion: reduce)", () => setComplete(true));
    return () => media.revert();
  }, []);

  return (
    <div className="receipt-anchor" ref={root}>
      <div className="sample-receipt" aria-hidden="true">
        <svg className="receipt-mark" width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <path d={check} />
        </svg>
        <div className="receipt-copy">
          <strong>Checked in</strong>
          <span>Sample only</span>
        </div>
      </div>
      <span role="status" className="visually-hidden">
        {complete ? "Sample check-in complete. No data was sent." : ""}
      </span>
    </div>
  );
}
