"use client";

import { useRef, useState } from "react";
import { ArrowUpRight, Building2, Camera, History, Play, RotateCcw } from "lucide-react";
import { Phone, screens } from "./phone";
import { SampleReceipt } from "./sample-receipt";

const icons = [Camera, History, Building2];

export function Tour() {
  const [active, setActive] = useState(0);
  const [play, setPlay] = useState(0);
  const stage = useRef(null);
  const screen = screens[active];
  const DemoIcon = play ? RotateCcw : Play;

  function runSample() {
    setPlay((run) => run + 1);
    stage.current.scrollIntoView({ block: "nearest", inline: "nearest" });
  }

  return (
    <div className="tour">
      <div className="tour-choices" aria-label="App screens" role="group">
        {screens.map((item, index) => {
          const Icon = icons[index];
          return (
            <button
              key={item.file}
              type="button"
              className="tour-option"
              aria-pressed={active === index}
              aria-controls="screen-preview"
              onClick={() => {
                if (index !== active) setPlay(0);
                setActive(index);
              }}
            >
              <Icon aria-hidden="true" size={21} />
              <span>{item.label}</span>
              <ArrowUpRight className="tour-arrow" aria-hidden="true" size={18} />
            </button>
          );
        })}
        <div className="tour-caption" aria-live="polite">
          <h3>{screen.title}</h3>
          <p>{screen.description}</p>
        </div>
        <div className="sample-action-slot">
          {active === 0 && (
            <button type="button" className="button button-sample" aria-controls="screen-preview" onClick={runSample}>
              <DemoIcon size={17} aria-hidden="true" />
              {play ? "Replay sample check-in" : "Play sample check-in"}
            </button>
          )}
        </div>
      </div>
      <figure className={`tour-stage stage-${screen.file}`} id="screen-preview" ref={stage}>
        <Phone gallery screen={screen}>
          {active === 0 && play > 0 && <SampleReceipt key={play} />}
        </Phone>
        <figcaption>Sample data</figcaption>
      </figure>
    </div>
  );
}
